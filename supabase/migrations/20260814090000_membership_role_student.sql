-- membership_role 에 'STUDENT' 추가 (학생 계정 기능)
--
-- 주의: `alter type ... add value` 로 추가한 enum 값은 같은 트랜잭션 안에서 참조할 수
-- 없다(Postgres 제약). 그래서 이 문장만 단독 마이그레이션 파일로 둔다.
-- STUDENT 값을 실제로 사용하는 정책/함수는 다음 파일(20260814091000)에 있다.

alter type public.membership_role add value if not exists 'STUDENT';
