-- 소셜 로그인 사용자의 real_name(이름)이 '미설정'으로 남는 문제 수정.
--
-- 소셜(구글/카카오/네이버)은 이름 하나만 제공 → 트리거가 full_name(닉네임)에만
-- 넣고 real_name(이름)은 비워 "이름 미설정"으로 보였다. 이메일 가입은 닉네임/실명을
-- 따로 받으므로 영향 없다.
--
-- 수정: real_name이 메타에 없으면 소셜 이름(full_name/name/nickname)으로 폴백.
-- (이메일 가입의 real_name은 메타에서 그대로 사용 → 기존 동작 유지)

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
begin
  insert into public.profiles (id, email, full_name, real_name)
  values (
    new.id,
    v_email,
    v_display,
    -- 이메일 가입: 폼의 real_name 사용. 소셜: 없으면 표시 이름으로 폴백.
    coalesce(nullif(new.raw_user_meta_data ->> 'real_name', ''), v_display)
  )
  on conflict (id) do update
  set email = excluded.email,
      real_name = coalesce(profiles.real_name, excluded.real_name);
  return new;
end;
$function$;

-- 이미 가입된 소셜 사용자(real_name 비어있음) 백필: 소셜 식별자 또는 소셜
-- 프로필 이미지(avatar_url/picture)를 가진 계정만 대상으로 표시 이름을 채운다.
update public.profiles p
set real_name = p.full_name
from auth.users u
where p.id = u.id
  and p.real_name is null
  and p.full_name is not null
  and (u.raw_user_meta_data ->> 'real_name') is null
  and (
    exists (
      select 1 from auth.identities i
      where i.user_id = u.id and i.provider in ('google', 'kakao', 'apple')
    )
    or (u.raw_user_meta_data ? 'avatar_url')
    or (u.raw_user_meta_data ? 'picture')
  );
