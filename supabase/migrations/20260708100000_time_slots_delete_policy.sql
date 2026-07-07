-- =====================================================
-- time_slots: missing DELETE RLS policy
-- =====================================================
-- time_slots에는 SELECT/INSERT/UPDATE 정책만 있고 DELETE 정책이 없었다. RLS가
-- 켜진 테이블은 정책이 없는 동작을 전부 거부하므로, 앱에서 교시를 삭제하려 해도
-- 항상 0건 처리되고 INSERT만 누적됐다. 그 결과 "교시 재설정"이 기존 교시를 지우지
-- 못한 채 새 교시를 얹어 슬롯이 쌓였고(예: 09:00-09:30과 09:00-09:50 공존, 29교시),
-- 결국 중복 INSERT가 unique(term_id, day_of_week, start_time, end_time) 제약과
-- 충돌(SQLSTATE 23505)했다.
--
-- INSERT/UPDATE와 동일하게 HOMESCHOOL_ADMIN / STAFF 에게 DELETE 를 허용한다.
-- (ARCHIVED 학기 보호는 기존 trg_guard_mutation_time_slots 트리거가 계속 담당)

drop policy if exists time_slots_delete_admin_staff on public.time_slots;
create policy time_slots_delete_admin_staff on public.time_slots
for delete using (
  public.has_term_role(term_id, array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[])
);
