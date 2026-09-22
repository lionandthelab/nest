-- media 버킷 정책 조이기
--
-- 앨범 작업 중 20260324120000_supabase_storage_media.sql의 정책 두 개에서
-- 구멍을 찾았다.
--
-- 1) media_select_public이 `using (bucket_id = 'media')` 뿐이라 익명 사용자도
--    /storage/v1/object/list/media 를 호출해 전체 오브젝트 목록을 훑을 수 있다.
--    홈스쿨 UUID → 연월 → 파일명이 그대로 노출된다. 공개 버킷이라 개별 파일
--    GET(/object/public/...)은 어차피 RLS를 타지 않으므로, 이 정책을 로그인
--    사용자로 좁혀도 화면에 붙는 이미지는 그대로 동작한다. 막히는 건 열거뿐이다.
--
-- 2) media_delete_authenticated는 로그인만 했으면 남의 홈스쿨 파일까지 지울 수
--    있었다. 본인이 올린 것이거나, 그 파일이 속한 홈스쿨의 관리자/스태프일
--    때로 좁힌다.
--
-- insert는 건드리지 않는다. 프로필 사진·공지 첨부·앨범이 서로 다른 경로 규칙을
-- 쓰고 있어, 지금 좁히면 정작 막아야 할 것보다 멀쩡한 업로드가 먼저 깨진다.

-- 경로 조각이 UUID 모양일 때만 캐스팅한다. 'avatars' 같은 조각을 그냥 uuid로
-- 캐스팅하면 정책 평가가 예외로 죽어 버킷 전체가 잠긴다.
create or replace function public.try_uuid(p_text text)
returns uuid
language sql
immutable
as $$
  select case
    when p_text ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
      then p_text::uuid
    else null
  end;
$$;

-- media 버킷 오브젝트 경로에서 소속 홈스쿨을 뽑는다.
--   앨범/갤러리 : {homeschool_id}/{YYYY-MM}/...
--   공지 첨부   : announcements/{homeschool_id}/{announcement_id}/...
--   프로필 사진 : avatars/{user_id}/...  → 홈스쿨 없음(개인 소유물)
create or replace function public.media_object_homeschool(p_object_name text)
returns uuid
language sql
immutable
as $$
  select case
    when (storage.foldername(p_object_name))[1] = 'announcements'
      then public.try_uuid((storage.foldername(p_object_name))[2])
    when (storage.foldername(p_object_name))[1] = 'avatars'
      then null
    else public.try_uuid((storage.foldername(p_object_name))[1])
  end;
$$;

grant execute on function public.try_uuid(text) to authenticated;
grant execute on function public.media_object_homeschool(text) to authenticated;

drop policy if exists "media_select_public" on storage.objects;
create policy "media_select_authenticated"
  on storage.objects for select
  using (
    bucket_id = 'media'
    and auth.role() = 'authenticated'
  );

drop policy if exists "media_delete_authenticated" on storage.objects;
create policy "media_delete_owner_or_admin"
  on storage.objects for delete
  using (
    bucket_id = 'media'
    and (
      owner = auth.uid()
      or (
        public.media_object_homeschool(name) is not null
        and public.has_homeschool_role(
          public.media_object_homeschool(name),
          array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
        )
      )
    )
  );
