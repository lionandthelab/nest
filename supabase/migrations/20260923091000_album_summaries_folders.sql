-- 폴더 뷰에 사용자가 만든 앨범 폴더도 카드로 세운다.
--
-- 20260922091000의 album_summaries는 학기·수업·반만 셌다. 사람이 실제로 찾는
-- 단위는 "가을 소풍" 같은 폴더인데, 폴더 뷰에 그게 안 보이면 폴더를 만들 이유가
-- 없어진다. FOLDER scope를 더한다.

create or replace function public.album_summaries(p_homeschool_id uuid)
returns table (
  scope text,
  scope_id uuid,
  scope_name text,
  item_count bigint,
  photo_count bigint,
  video_count bigint,
  latest_captured_at timestamptz,
  cover_storage_path text,
  cover_thumbnail_path text
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if p_homeschool_id is null or not public.is_homeschool_member(p_homeschool_id) then
    raise exception '홈스쿨 권한이 없습니다.';
  end if;

  return query
  with scoped as (
    select 'TERM'::text as s_scope, ma.term_id as s_id,
           coalesce(ma.captured_at, ma.created_at) as s_at,
           ma.media_type as s_type, ma.storage_path as s_path,
           ma.thumbnail_path as s_thumb
      from public.media_assets ma
     where ma.homeschool_id = p_homeschool_id and ma.term_id is not null
    union all
    select 'COURSE'::text, ma.course_id,
           coalesce(ma.captured_at, ma.created_at),
           ma.media_type, ma.storage_path, ma.thumbnail_path
      from public.media_assets ma
     where ma.homeschool_id = p_homeschool_id and ma.course_id is not null
    union all
    select 'CLASS_GROUP'::text, ma.class_group_id,
           coalesce(ma.captured_at, ma.created_at),
           ma.media_type, ma.storage_path, ma.thumbnail_path
      from public.media_assets ma
     where ma.homeschool_id = p_homeschool_id and ma.class_group_id is not null
    union all
    select 'FOLDER'::text, ma.album_folder_id,
           coalesce(ma.captured_at, ma.created_at),
           ma.media_type, ma.storage_path, ma.thumbnail_path
      from public.media_assets ma
     where ma.homeschool_id = p_homeschool_id and ma.album_folder_id is not null
  ),
  agg as (
    select s.s_scope, s.s_id,
           count(*) as n_all,
           count(*) filter (where s.s_type = 'PHOTO') as n_photo,
           count(*) filter (where s.s_type = 'VIDEO') as n_video,
           max(s.s_at) as n_latest
      from scoped s
     group by s.s_scope, s.s_id
  ),
  cover as (
    select distinct on (s.s_scope, s.s_id)
           s.s_scope, s.s_id, s.s_path, s.s_thumb
      from scoped s
     order by s.s_scope, s.s_id, (s.s_type = 'PHOTO') desc, s.s_at desc
  )
  select a.s_scope,
         a.s_id,
         coalesce(t.name, c.name, cg.name, af.name, ''),
         a.n_all, a.n_photo, a.n_video, a.n_latest,
         cv.s_path, cv.s_thumb
    from agg a
    left join public.terms t         on a.s_scope = 'TERM'        and t.id  = a.s_id
    left join public.courses c       on a.s_scope = 'COURSE'      and c.id  = a.s_id
    left join public.class_groups cg on a.s_scope = 'CLASS_GROUP' and cg.id = a.s_id
    left join public.album_folders af on a.s_scope = 'FOLDER'     and af.id = a.s_id
    left join cover cv on cv.s_scope = a.s_scope and cv.s_id = a.s_id
   order by (a.s_scope = 'FOLDER') desc, a.n_latest desc nulls last;
end;
$$;

grant execute on function public.album_summaries(uuid) to authenticated;
