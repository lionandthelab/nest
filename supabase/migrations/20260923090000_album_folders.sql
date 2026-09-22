-- 앨범 폴더
--
-- 지금까지 앨범은 학기·수업·반이라는 이미 있는 축으로만 묶였다. 그런데 사진을
-- 올리는 사람이 실제로 떠올리는 단위는 "가을 소풍", "김장 체험"처럼 행사
-- 이름이다. Google Drive에서 폴더를 만들어 넣듯, 앨범에서도 직접 만든 폴더에
-- 넣을 수 있게 한다. 이 폴더 이름이 곧 관리자 Drive의 폴더 이름이 된다.

create table if not exists public.album_folders (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  term_id uuid references public.terms(id) on delete set null,
  name text not null check (length(btrim(name)) > 0),
  created_by_user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 같은 학기 안에서 이름이 겹치면 Drive 폴더도 헷갈린다. term_id가 null인
-- (학기 없는) 폴더끼리도 이름이 겹치지 않게 coalesce로 묶는다.
create unique index if not exists album_folders_unique_name
  on public.album_folders (
    homeschool_id,
    coalesce(term_id, '00000000-0000-0000-0000-000000000000'::uuid),
    lower(btrim(name))
  );

create index if not exists idx_album_folders_school
  on public.album_folders (homeschool_id, term_id, created_at desc);

alter table public.media_assets
  add column if not exists album_folder_id uuid
    references public.album_folders(id) on delete set null;

create index if not exists idx_media_assets_album_folder
  on public.media_assets (homeschool_id, album_folder_id, captured_at desc)
  where album_folder_id is not null;

drop trigger if exists trg_album_folders_updated_at on public.album_folders;
create trigger trg_album_folders_updated_at
before update on public.album_folders
for each row execute function public.set_updated_at();

alter table public.album_folders enable row level security;

-- 조회: 홈스쿨 구성원 (media_assets_select_member와 같은 기준)
drop policy if exists album_folders_select_member on public.album_folders;
create policy album_folders_select_member on public.album_folders
for select using (public.is_homeschool_member(homeschool_id));

-- 생성: 사진을 올릴 수 있는 사람이면 폴더도 만들 수 있다. 올릴 곳이 없으면
-- 올릴 수 없으니, 업로드 권한과 같은 집합으로 둔다.
drop policy if exists album_folders_insert_uploader on public.album_folders;
create policy album_folders_insert_uploader on public.album_folders
for insert with check (
  created_by_user_id = auth.uid()
  and public.has_homeschool_role(
    homeschool_id,
    array[
      'HOMESCHOOL_ADMIN', 'STAFF', 'TEACHER', 'GUEST_TEACHER', 'PARENT'
    ]::public.membership_role[]
  )
);

-- 이름 변경·삭제: 만든 사람 또는 관리자/스태프. 삭제해도 사진은 남는다
-- (album_folder_id가 null로 풀릴 뿐) — 폴더를 지웠다고 사진을 잃으면 안 된다.
drop policy if exists album_folders_update_owner_or_admin on public.album_folders;
create policy album_folders_update_owner_or_admin on public.album_folders
for update using (
  created_by_user_id = auth.uid()
  or public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

drop policy if exists album_folders_delete_owner_or_admin on public.album_folders;
create policy album_folders_delete_owner_or_admin on public.album_folders
for delete using (
  created_by_user_id = auth.uid()
  or public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);
