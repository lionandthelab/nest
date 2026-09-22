-- Google Drive 폴더 구조 캐시
--
-- 앨범 업로드는 관리자 Drive에 "루트/학기/수업/날짜" 경로를 만들어 넣는다.
-- 매 파일마다 경로 세 단계를 Drive API로 조회·생성하면 업로드 한 건에 왕복이
-- 3~6회 더 붙는다. 한 번 만든 폴더 id를 경로 문자열로 캐시해 두 번째 파일부터는
-- 조회 없이 바로 업로드한다.
--
-- 기존 drive_folder_mappings는 mapping_type enum('TERM','CLASS_GROUP','CHILD')에
-- 묶여 있어 날짜 단계를 담지 못한다. enum 확장 대신 경로 문자열 키를 쓰는
-- 별도 테이블로 둔다.

create table if not exists public.drive_folder_nodes (
  id uuid primary key default gen_random_uuid(),
  drive_integration_id uuid not null
    references public.drive_integrations(id) on delete cascade,
  path_key text not null,
  folder_id text not null,
  created_at timestamptz not null default now(),
  unique (drive_integration_id, path_key)
);

create index if not exists idx_drive_folder_nodes_integration
  on public.drive_folder_nodes(drive_integration_id);

alter table public.drive_folder_nodes enable row level security;

-- 읽기만 구성원에게 연다. 쓰기는 edge function(서비스 키)만 한다 — 정책을 만들지
-- 않으면 서비스 롤만 통과하므로 별도 insert/update 정책을 두지 않는다.
drop policy if exists drive_folder_nodes_select_member on public.drive_folder_nodes;
create policy drive_folder_nodes_select_member on public.drive_folder_nodes
for select using (
  exists (
    select 1
    from public.drive_integrations di
    where di.id = drive_integration_id
      and public.is_homeschool_member(di.homeschool_id)
  )
);
