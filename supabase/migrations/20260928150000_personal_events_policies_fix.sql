-- personal_events RLS 정책 보강
-- 관리자/스태프 및 작성자 본인의 SELECT/INSERT/UPDATE/DELETE 권한을 명시하여
-- 관리자가 자녀 일정을 등록하거나 부모/관리자 모드에서 개인 일정을 추가할 때
-- RLS 위반 에러가 발생하지 않도록 수정한다.

-- 1) SELECT 정책 재작성
drop policy if exists personal_events_select_family on public.personal_events;

create policy personal_events_select_family
  on public.personal_events for select
  using (
    owner_user_id = auth.uid()
    or public.is_child_guardian(child_id)
    or public.is_child_self(child_id)
    or public.has_homeschool_role(
      homeschool_id,
      array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
    )
  );

-- 2) INSERT 정책 재작성
drop policy if exists personal_events_insert_family on public.personal_events;

create policy personal_events_insert_family
  on public.personal_events for insert
  with check (
    owner_user_id = auth.uid()
    and (
      public.is_child_guardian(child_id)
      or public.is_child_self(child_id)
      or public.has_homeschool_role(
        homeschool_id,
        array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
      )
    )
    and exists (
      select 1
      from public.children c
      join public.families f on f.id = c.family_id
      where c.id = child_id
        and f.homeschool_id = personal_events.homeschool_id
    )
  );

-- 3) UPDATE 정책 재작성
drop policy if exists personal_events_update_family on public.personal_events;

create policy personal_events_update_family
  on public.personal_events for update
  using (
    owner_user_id = auth.uid()
    or public.is_child_guardian(child_id)
    or public.is_child_self(child_id)
    or public.has_homeschool_role(
      homeschool_id,
      array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
    )
  )
  with check (
    owner_user_id = auth.uid()
    or public.is_child_guardian(child_id)
    or public.is_child_self(child_id)
    or public.has_homeschool_role(
      homeschool_id,
      array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
    )
  );

-- 4) DELETE 정책 재작성
drop policy if exists personal_events_delete_family on public.personal_events;

create policy personal_events_delete_family
  on public.personal_events for delete
  using (
    owner_user_id = auth.uid()
    or public.is_child_guardian(child_id)
    or public.is_child_self(child_id)
    or public.has_homeschool_role(
      homeschool_id,
      array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
    )
  );

-- 5) authenticated 권한 보장
grant select, insert, update, delete on public.personal_events to authenticated;
