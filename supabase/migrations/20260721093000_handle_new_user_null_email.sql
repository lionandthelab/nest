-- 소셜 로그인(카카오 등) 이메일 미제공 계정에서 신규 가입이 실패하는 문제 수정.
--
-- 배경: handle_new_user()가 profiles(email)에 new.email을 그대로 넣는데
-- profiles.email이 NOT NULL이다. 카카오는 이메일이 선택 동의라 미제공 시
-- new.email=NULL → NOT NULL 위반 → "Database error saving new user" (GoTrue 500).
--
-- 수정: 이메일이 없으면 계정 id 기반 대체 이메일을 채워 NOT NULL 불변식을 유지한다.
-- (email 컬럼을 nullable로 바꾸지 않아 기존 조회/표시 코드에 영향 없음)
-- full_name도 name/nickname 순으로 폴백해 소셜 계정 이름을 최대한 채운다.

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
begin
  insert into public.profiles (id, email, full_name, real_name)
  values (
    new.id,
    v_email,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(new.raw_user_meta_data ->> 'name', ''),
      nullif(new.raw_user_meta_data ->> 'nickname', ''),
      split_part(v_email, '@', 1)
    ),
    nullif(new.raw_user_meta_data ->> 'real_name', '')
  )
  on conflict (id) do update
  set email = excluded.email,
      real_name = coalesce(profiles.real_name, excluded.real_name);
  return new;
end;
$function$;
