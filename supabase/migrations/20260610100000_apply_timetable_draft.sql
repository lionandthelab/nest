-- 시간표 드래프트 원자적 일괄 적용 RPC (apply_timetable_draft)
--
-- 배경: 시간표 편집기의 "확정" 동작은 현재 클라이언트에서 여러 번의
-- 개별 호출(삭제/이동/위치변경/생성 + 교사 배정 재구성)로 수행된다.
-- 이 함수는 동일한 커밋 의미를 단일 트랜잭션으로 묶어, 도중에 실패하면
-- (RLS 거부, TEACHER_SLOT_CONFLICT 트리거, ARCHIVED 학기 차단 등) 전부
-- 롤백되도록 한다.
--
-- 안전성: SECURITY INVOKER(기본값)로 정의하여 호출자의 RLS/트리거가
-- 그대로 적용된다. 별도의 역할 검증 코드를 두지 않으며, 기존
-- class_sessions / session_teacher_assignments 의 HOMESCHOOL_ADMIN/STAFF
-- RLS 정책이 권한을 강제한다. SECURITY DEFINER 를 사용하지 않는다.
--
-- p_sessions: JSON 배열. 각 원소 형태:
--   {
--     "id": uuid|null,            -- null 이면 신규 생성, 아니면 기존 세션 갱신
--     "course_id": uuid,
--     "time_slot_id": uuid,
--     "title": text,
--     "location": text|null,
--     "main_teacher_id": uuid|null,
--     "assistant_ids": [uuid, ...]
--   }
-- p_deleted_ids: 드래프트에 없어 서버에서 제거할 세션 id 배열(하드 삭제).

create or replace function public.apply_timetable_draft(
  p_class_group_id uuid,
  p_sessions jsonb,
  p_deleted_ids uuid[]
)
returns jsonb
language plpgsql
as $$
declare
  v_user_id uuid := auth.uid();
  v_element jsonb;
  v_session_id uuid;
  v_main_teacher uuid;
  v_assistant uuid;
  v_resolved_ids uuid[] := array[]::uuid[];
begin
  -- (a) 드래프트에 없는 기존 세션 하드 삭제.
  if p_deleted_ids is not null and array_length(p_deleted_ids, 1) is not null then
    delete from public.class_sessions
    where id = any(p_deleted_ids)
      and class_group_id = p_class_group_id;
  end if;

  -- (b)(c) 드래프트 세션을 순회하며 생성/갱신하고 최종 세션 id 를 수집.
  for v_element in
    select * from jsonb_array_elements(coalesce(p_sessions, '[]'::jsonb))
  loop
    -- null 로 시작: 기존 id 가 이 반에 속하지 않아 UPDATE 가 0행이면
    -- RETURNING INTO 가 null 을 넣으므로, 외부 반의 배정은 건드리지 않는다.
    v_session_id := null;

    if v_element->>'id' is null then
      insert into public.class_sessions (
        class_group_id,
        course_id,
        time_slot_id,
        title,
        location,
        source_type,
        status,
        created_by_user_id
      )
      values (
        p_class_group_id,
        (v_element->>'course_id')::uuid,
        (v_element->>'time_slot_id')::uuid,
        v_element->>'title',
        coalesce(nullif(trim(v_element->>'location'), ''), '미정'),
        'MANUAL',
        'PLANNED',
        v_user_id
      )
      returning id into v_session_id;
    else
      -- source_type 은 보존한다(폴백 경로와 동일). 기존 세션의 출처(AI 등)를
      -- 단순 편집으로 MANUAL 로 덮어쓰지 않는다.
      update public.class_sessions
      set time_slot_id = (v_element->>'time_slot_id')::uuid,
          location = coalesce(nullif(trim(v_element->>'location'), ''), '미정')
      where id = (v_element->>'id')::uuid
        and class_group_id = p_class_group_id
      returning id into v_session_id;
    end if;

    -- 미해석(null)도 배열에 넣어 p_sessions 와 인덱스 정렬을 유지한다.
    v_resolved_ids := v_resolved_ids || v_session_id;
  end loop;

  -- (d) 교사 배정 재구성: 먼저 전부 제거하여 일시적 자기충돌을 피한 뒤
  -- MAIN(있으면) + ASSISTANT 들을 다시 삽입한다. 삽입 시 교사 이중배정
  -- 트리거가 동작하며, 실제 충돌이면 함수 전체가 롤백된다.
  if array_length(v_resolved_ids, 1) is not null then
    delete from public.session_teacher_assignments
    where class_session_id = any(v_resolved_ids);
  end if;

  -- 배정 삽입은 해석된 세션 id 와 원본 요소를 함께 사용해야 하므로
  -- p_sessions 와 v_resolved_ids 를 인덱스로 매칭하여 처리한다.
  declare
    v_index int := 0;
  begin
    for v_element in
      select * from jsonb_array_elements(coalesce(p_sessions, '[]'::jsonb))
    loop
      v_index := v_index + 1;
      v_session_id := v_resolved_ids[v_index];
      if v_session_id is null then
        continue;
      end if;

      v_main_teacher := nullif(v_element->>'main_teacher_id', '')::uuid;

      if v_main_teacher is not null then
        insert into public.session_teacher_assignments (
          class_session_id,
          teacher_profile_id,
          assignment_role
        )
        values (v_session_id, v_main_teacher, 'MAIN');
      end if;

      for v_assistant in
        select (value)::uuid
        from jsonb_array_elements_text(
          coalesce(v_element->'assistant_ids', '[]'::jsonb)
        )
      loop
        if v_main_teacher is not null and v_assistant = v_main_teacher then
          continue;
        end if;
        insert into public.session_teacher_assignments (
          class_session_id,
          teacher_profile_id,
          assignment_role
        )
        values (v_session_id, v_assistant, 'ASSISTANT');
      end loop;
    end loop;
  end;

  return jsonb_build_object(
    'applied', coalesce(array_length(array_remove(v_resolved_ids, null), 1), 0),
    'ids', to_jsonb(array_remove(v_resolved_ids, null))
  );
end;
$$;

grant execute on function public.apply_timetable_draft(uuid, jsonb, uuid[]) to authenticated;
