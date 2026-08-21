-- profiles.phone 실제 채우기 (문자/알림톡 발송의 전제조건)
--
-- 배경: profiles.phone 컬럼은 처음부터 존재했지만 아무도 쓰지 않아 사실상 전부 비어
-- 있다. 앱 회원가입은 전화번호를 auth.users.raw_user_meta_data->>'phone_number' 에만
-- 넣는다. 수업 변경 알림 / 결석 신고 알림은 수신자 user_id → 전화번호 해석이 필요하고,
-- Edge Function 이 auth 스키마를 매번 조회하는 것보다 profiles 한 곳에서 읽는 편이
-- 안전하고 빠르다. 그래서 가입 트리거·메타데이터 동기화 트리거·기존 사용자 백필의
-- 세 경로 모두에서 profiles.phone 을 채운다.
--
-- 안전장치: 정규화(normalize_kr_phone)에 실패한 값은 절대 저장하지 않는다.
-- 형식이 깨진 번호를 그대로 넣으면 "엉뚱한 사람에게 문자가 가는" 사고로 직결된다.
-- 저장 포맷은 하이픈 없는 국내 표기(예: 01012345678) 하나로 통일한다.
--
-- 기존 동작 보존: handle_new_user / handle_user_metadata_sync 는 현재 정의를 그대로
-- 옮기고 phone 처리만 추가한다(이메일 폴백, full_name/real_name 폴백 규칙 불변).

-- =====================================================
-- 1) 한국 휴대폰 번호 정규화
-- =====================================================

create or replace function public.normalize_kr_phone(p_raw text)
returns text
language plpgsql
immutable
set search_path = public
as $$
declare
  v_digits text;
begin
  if p_raw is null then
    return null;
  end if;

  -- 숫자만 남긴다('+82 10-1234-5678' → '821012345678').
  v_digits := regexp_replace(p_raw, '[^0-9]', '', 'g');

  if v_digits = '' then
    return null;
  end if;

  -- 국가번호 82 → 0 (국내 휴대폰 번호는 항상 01 로 시작하므로 오탐 없음).
  if left(v_digits, 2) = '82' then
    v_digits := '0' || substring(v_digits from 3);
  end if;

  -- 국내 휴대폰 형식만 통과시킨다. 유선/대표번호/깨진 값은 null.
  if v_digits ~ '^01[016789][0-9]{7,8}$' then
    return v_digits;
  end if;

  return null;
end;
$$;

comment on function public.normalize_kr_phone(text) is
  '국내 휴대폰 번호를 하이픈 없는 01x형식으로 정규화. 형식 불일치면 null.';

-- =====================================================
-- 2) 신규 가입 트리거 (기존 동작 + phone)
-- =====================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_email text := coalesce(
    nullif(new.email, ''),
    nullif(new.raw_user_meta_data ->> 'email', ''),
    new.id::text || '@no-email.social'
  );
  v_display text := coalesce(
    nullif(new.raw_user_meta_data ->> 'full_name', ''),
    nullif(new.raw_user_meta_data ->> 'name', ''),
    nullif(new.raw_user_meta_data ->> 'nickname', ''),
    nullif(new.raw_user_meta_data ->> 'preferred_username', ''),
    split_part(v_email, '@', 1)
  );
  v_phone text := coalesce(
    public.normalize_kr_phone(nullif(new.raw_user_meta_data ->> 'phone_number', '')),
    public.normalize_kr_phone(nullif(new.raw_user_meta_data ->> 'phone', '')),
    public.normalize_kr_phone(nullif(new.phone, ''))
  );
begin
  insert into public.profiles (id, email, full_name, real_name, phone)
  values (
    new.id,
    v_email,
    v_display,
    -- 이메일 가입: 폼의 real_name 사용. 소셜: 없으면 표시 이름으로 폴백.
    coalesce(nullif(new.raw_user_meta_data ->> 'real_name', ''), v_display),
    v_phone
  )
  on conflict (id) do update
  set email = excluded.email,
      real_name = coalesce(profiles.real_name, excluded.real_name),
      -- 이미 저장된 번호는 덮어쓰지 않는다(관리자가 고쳐둔 값 보호).
      phone = coalesce(nullif(profiles.phone, ''), excluded.phone);
  return new;
end;
$function$;

-- =====================================================
-- 3) 메타데이터 갱신 동기화 트리거 (기존 동작 + phone)
-- =====================================================

create or replace function public.handle_user_metadata_sync()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  update public.profiles p set
    full_name = coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(new.raw_user_meta_data ->> 'name', ''),
      nullif(new.raw_user_meta_data ->> 'nickname', ''),
      p.full_name
    ),
    real_name = coalesce(
      nullif(new.raw_user_meta_data ->> 'real_name', ''),
      nullif(new.raw_user_meta_data ->> 'name', ''),
      p.real_name
    ),
    -- 정규화 실패값은 null 이 되어 coalesce 가 기존 값을 유지한다.
    phone = coalesce(
      public.normalize_kr_phone(nullif(new.raw_user_meta_data ->> 'phone_number', '')),
      public.normalize_kr_phone(nullif(new.raw_user_meta_data ->> 'phone', '')),
      p.phone
    )
  where p.id = new.id;
  return new;
end;
$function$;

drop trigger if exists on_auth_user_meta_sync on auth.users;
create trigger on_auth_user_meta_sync
  after update of raw_user_meta_data on auth.users
  for each row
  execute function public.handle_user_metadata_sync();

-- =====================================================
-- 4) 기존 사용자 백필 (비어 있는 행만)
-- =====================================================

update public.profiles p
set phone = public.normalize_kr_phone(
      coalesce(
        nullif(u.raw_user_meta_data ->> 'phone_number', ''),
        nullif(u.raw_user_meta_data ->> 'phone', ''),
        nullif(u.phone, '')
      )
    )
from auth.users u
where u.id = p.id
  and coalesce(p.phone, '') = ''
  and public.normalize_kr_phone(
        coalesce(
          nullif(u.raw_user_meta_data ->> 'phone_number', ''),
          nullif(u.raw_user_meta_data ->> 'phone', ''),
          nullif(u.phone, '')
        )
      ) is not null;

create index if not exists idx_profiles_phone
  on public.profiles (phone)
  where phone is not null;
