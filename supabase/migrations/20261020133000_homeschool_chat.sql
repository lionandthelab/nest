-- 홈스쿨 실시간 채팅 메시지 테이블 및 RLS/스토리지/Realtime 설정
--
-- 기능 요약:
-- 1) 홈스쿨 전체 단톡방(class_group_id IS NULL, recipient_user_id IS NULL),
--    반별 단톡방(class_group_id IS NOT NULL),
--    1:1 대화(recipient_user_id IS NOT NULL)를 단일 테이블에서 지원한다.
-- 2) message_type 으로 일반 텍스트('TEXT'), 사진('IMAGE'), 동영상('VIDEO'),
--    스케줄('SCHEDULE'), 연락처('CONTACT'), 일반 파일('FILE') 공유를 구분하고,
--    첨부·스케줄·연락처의 상세 정보는 metadata(jsonb)에 구조화해 저장한다.
-- 3) media 버킷의 chat/{homeschool_id}/... 경로를 media_object_homeschool()에
--    등록하여 관리자/작성자 삭제 정책과 통합한다.
-- 4) supabase_realtime publication 에 등록하여 실시간 수신을 지원한다.

create table if not exists public.homeschool_chat_messages (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  class_group_id uuid references public.class_groups(id) on delete cascade,
  recipient_user_id uuid references auth.users(id) on delete cascade,
  sender_user_id uuid not null references auth.users(id) on delete cascade,
  sender_name text not null default '',
  sender_role text not null default '',
  message_type text not null default 'TEXT'
    check (message_type in ('TEXT', 'IMAGE', 'VIDEO', 'SCHEDULE', 'CONTACT', 'FILE')),
  content text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_homeschool_chat_messages_hs_created
  on public.homeschool_chat_messages(homeschool_id, created_at desc);

create index if not exists idx_homeschool_chat_messages_class
  on public.homeschool_chat_messages(class_group_id, created_at desc)
  where class_group_id is not null;

create index if not exists idx_homeschool_chat_messages_dm
  on public.homeschool_chat_messages(homeschool_id, sender_user_id, recipient_user_id, created_at desc)
  where recipient_user_id is not null;

drop trigger if exists set_homeschool_chat_messages_updated_at on public.homeschool_chat_messages;
create trigger set_homeschool_chat_messages_updated_at
  before update on public.homeschool_chat_messages
  for each row execute function public.set_updated_at();

alter table public.homeschool_chat_messages enable row level security;

-- 조회: 해당 홈스쿨의 ACTIVE 구성원이면서,
-- 전체/반별 메시지는 구성원 모두 조회 가능하고, 1:1 메시지는 발신자 또는 수신자 본인만 조회 가능
drop policy if exists "homeschool_chat_messages_select_member" on public.homeschool_chat_messages;
create policy "homeschool_chat_messages_select_member"
  on public.homeschool_chat_messages for select
  using (
    public.is_homeschool_member(homeschool_id)
    and (
      recipient_user_id is null
      or sender_user_id = auth.uid()
      or recipient_user_id = auth.uid()
    )
  );

-- 작성: 본인 user_id 로만 해당 홈스쿨에 메시지 등록 가능
drop policy if exists "homeschool_chat_messages_insert_member" on public.homeschool_chat_messages;
create policy "homeschool_chat_messages_insert_member"
  on public.homeschool_chat_messages for insert
  with check (
    sender_user_id = auth.uid()
    and public.is_homeschool_member(homeschool_id)
  );

-- 수정: 작성자 본인 또는 홈스쿨 관리자/스태프
drop policy if exists "homeschool_chat_messages_update_sender_or_admin" on public.homeschool_chat_messages;
create policy "homeschool_chat_messages_update_sender_or_admin"
  on public.homeschool_chat_messages for update
  using (
    sender_user_id = auth.uid()
    or public.has_homeschool_role(
      homeschool_id,
      array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
    )
  );

-- 삭제: 작성자 본인 또는 홈스쿨 관리자/스태프
drop policy if exists "homeschool_chat_messages_delete_sender_or_admin" on public.homeschool_chat_messages;
create policy "homeschool_chat_messages_delete_sender_or_admin"
  on public.homeschool_chat_messages for delete
  using (
    sender_user_id = auth.uid()
    or public.has_homeschool_role(
      homeschool_id,
      array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
    )
  );

-- media 버킷의 chat/{homeschool_id}/{message_id}/... 경로도 홈스쿨 소속으로 인식
create or replace function public.media_object_homeschool(p_object_name text)
returns uuid
language sql
immutable
as $$
  select case
    when (storage.foldername(p_object_name))[1] in ('announcements', 'chat')
      then public.try_uuid((storage.foldername(p_object_name))[2])
    when (storage.foldername(p_object_name))[1] = 'avatars'
      then null
    else public.try_uuid((storage.foldername(p_object_name))[1])
  end;
$$;

grant execute on function public.media_object_homeschool(text) to authenticated;

-- Supabase Realtime publication 등록 (중복 등록 무시)
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'homeschool_chat_messages'
    ) then
      alter publication supabase_realtime add table public.homeschool_chat_messages;
    end if;
  end if;
exception
  when others then
    raise notice 'supabase_realtime 등록 건너뜀: %', sqlerrm;
end;
$$;
