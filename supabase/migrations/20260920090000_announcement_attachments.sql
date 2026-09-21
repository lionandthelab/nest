-- 공지사항 첨부파일
--
-- 공지사항에 파일(가정통신문 PDF, 안내 이미지 등)을 첨부할 수 있게 한다. 파일
-- 자체는 기존 공개 'media' 스토리지 버킷(20260324120000_supabase_storage_media.sql)의
-- announcements/ 경로에 저장하고, 이 테이블은 그 경로와 원본 파일명·MIME 타입만
-- 기록한다. 버킷 정책이 이미 인증된 사용자의 임의 경로 read/write/delete를
-- 허용하므로 별도 스토리지 정책은 필요 없다.

create table if not exists public.announcement_attachments (
  id uuid primary key default gen_random_uuid(),
  announcement_id uuid not null references public.announcements(id) on delete cascade,
  uploader_user_id uuid not null references auth.users(id) on delete restrict,
  storage_path text not null,
  file_name text not null,
  mime_type text not null,
  size_bytes bigint not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists idx_announcement_attachments_announcement
  on public.announcement_attachments(announcement_id);

alter table public.announcement_attachments enable row level security;

-- select: 그 공지가 속한 홈스쿨의 구성원이면 조회 가능 (announcements_select_member와 동일 기준)
drop policy if exists announcement_attachments_select_member on public.announcement_attachments;
create policy announcement_attachments_select_member on public.announcement_attachments
for select using (
  exists (
    select 1
    from public.announcements a
    where a.id = announcement_id
      and public.is_homeschool_member(a.homeschool_id)
  )
);

-- insert/delete: 그 공지의 작성자 본인 또는 관리자/스태프
-- (announcements_update_teacher_admin / announcements_delete_teacher_admin과 동일 기준)
drop policy if exists announcement_attachments_insert_author_or_admin on public.announcement_attachments;
create policy announcement_attachments_insert_author_or_admin on public.announcement_attachments
for insert with check (
  exists (
    select 1
    from public.announcements a
    where a.id = announcement_id
      and (
        a.author_user_id = auth.uid()
        or public.has_homeschool_role(
          a.homeschool_id,
          array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
        )
      )
  )
);

drop policy if exists announcement_attachments_delete_author_or_admin on public.announcement_attachments;
create policy announcement_attachments_delete_author_or_admin on public.announcement_attachments
for delete using (
  exists (
    select 1
    from public.announcements a
    where a.id = announcement_id
      and (
        a.author_user_id = auth.uid()
        or public.has_homeschool_role(
          a.homeschool_id,
          array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
        )
      )
  )
);
