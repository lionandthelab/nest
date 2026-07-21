-- 소셜 재로그인으로 auth 메타데이터(별명→full_name / 이름→real_name)가 갱신되면
-- profiles도 맞춰 동기화한다. handle_new_user는 INSERT에만 걸려서, 기존 사용자가
-- 재로그인해도 profiles가 안 바뀌던 문제를 해결(브로커가 매 로그인 메타데이터 갱신).

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
