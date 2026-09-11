-- 시간표/달력 첫 화면: 학기 세션+교사 배정을 한 번에 읽고,
-- 자주 쓰는 필터용 인덱스를 보탠다.

create index if not exists idx_class_sessions_group_active
  on public.class_sessions (class_group_id, time_slot_id)
  where status <> 'CANCELED';

create index if not exists idx_academic_events_school_term
  on public.academic_events (homeschool_id, term_id, event_date);

create or replace function public.fetch_term_schedule_pack(p_term_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_term_id is null or not public.is_term_member(p_term_id) then
    raise exception '학기 권한이 없습니다.';
  end if;

  return jsonb_build_object(
    'sessions', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', cs.id,
          'class_group_id', cs.class_group_id,
          'course_id', cs.course_id,
          'time_slot_id', cs.time_slot_id,
          'title', cs.title,
          'source_type', cs.source_type,
          'status', cs.status,
          'location', cs.location
        )
        order by cs.class_group_id, cs.time_slot_id
      )
      from public.class_sessions cs
      join public.class_groups cg on cg.id = cs.class_group_id
      where cg.term_id = p_term_id
        and cs.status <> 'CANCELED'
    ), '[]'::jsonb),
    'assignments', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', sta.id,
          'class_session_id', sta.class_session_id,
          'teacher_profile_id', sta.teacher_profile_id,
          'assignment_role', sta.assignment_role
        )
      )
      from public.session_teacher_assignments sta
      join public.class_sessions cs on cs.id = sta.class_session_id
      join public.class_groups cg on cg.id = cs.class_group_id
      where cg.term_id = p_term_id
        and cs.status <> 'CANCELED'
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.fetch_term_schedule_pack(uuid) from public;
grant execute on function public.fetch_term_schedule_pack(uuid) to authenticated;
