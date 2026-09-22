-- 앨범(갤러리) 강화: 학기·수업 축과 목록 조회에 필요한 메타데이터
--
-- 기존 media_assets는 class_group_id 하나로만 묶여 있어서 "학기별/수업별 앨범"을
-- 만들려면 class_groups를 매번 조인해야 했고, 그리드에는 원본 이미지를 그대로
-- 내려받아 붙이고 있었다. 앨범 화면이 학기·수업·날짜로 좁혀 읽고 썸네일만
-- 먼저 받도록, 필터 축(term_id/course_id)과 파일 메타데이터를 컬럼으로 승격한다.
--
-- term_id는 class_group_id로부터 유도할 수 있지만 일부러 중복 저장한다.
-- (1) 수업 배정 없이 학기 앨범에만 올리는 경우를 허용하고,
-- (2) 목록 질의가 조인 없이 단일 인덱스로 끝나게 하기 위함이다.

alter table public.media_assets
  add column if not exists term_id uuid references public.terms(id) on delete set null,
  add column if not exists course_id uuid references public.courses(id) on delete set null,
  add column if not exists thumbnail_path text,
  add column if not exists file_name text,
  add column if not exists mime_type text,
  add column if not exists size_bytes bigint,
  add column if not exists drive_folder_id text;

-- 기존 행 백필: 반이 지정돼 있으면 그 반이 속한 학기로 채운다.
update public.media_assets ma
   set term_id = cg.term_id
  from public.class_groups cg
 where ma.class_group_id = cg.id
   and ma.term_id is null;

-- 기존 행 백필: 수업 세션이 지정돼 있으면 그 세션의 과목으로 채운다.
update public.media_assets ma
   set course_id = cs.course_id
  from public.class_sessions cs
 where ma.class_session_id = cs.id
   and ma.course_id is null;

-- captured_at 내림차순이 앨범의 기본 정렬이다. 기존 idx_media_assets_school은
-- created_at 기준이라 이 정렬에는 쓰이지 않는다.
create index if not exists idx_media_assets_album
  on public.media_assets(homeschool_id, captured_at desc);

create index if not exists idx_media_assets_album_term
  on public.media_assets(homeschool_id, term_id, captured_at desc)
  where term_id is not null;

create index if not exists idx_media_assets_album_course
  on public.media_assets(homeschool_id, course_id, captured_at desc)
  where course_id is not null;

create index if not exists idx_media_assets_album_class_group
  on public.media_assets(homeschool_id, class_group_id, captured_at desc)
  where class_group_id is not null;

create index if not exists idx_media_assets_album_uploader
  on public.media_assets(homeschool_id, uploader_user_id, captured_at desc);

-- delete 정책이 없어 지금까지는 업로더 본인도 사진을 지울 수 없었다.
-- 앨범에서 잘못 올린 파일을 거두려면 필요하다. 기준은 update 정책과 맞춘다.
drop policy if exists media_assets_delete_uploader_or_admin on public.media_assets;
create policy media_assets_delete_uploader_or_admin on public.media_assets
for delete using (
  uploader_user_id = auth.uid()
  or public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
);

-- 태그 해제(사진 수정) 경로도 같은 기준으로 열어 준다.
drop policy if exists media_asset_children_delete_uploader_or_admin on public.media_asset_children;
create policy media_asset_children_delete_uploader_or_admin on public.media_asset_children
for delete using (
  exists (
    select 1
    from public.media_assets ma
    where ma.id = media_asset_id
      and (
        ma.uploader_user_id = auth.uid()
        or public.has_homeschool_role(
          ma.homeschool_id,
          array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
        )
      )
  )
);
