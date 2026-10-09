-- 홈스쿨을 만들 때 참여 코드가 비어 있으면 바로 채운다.
--
-- join_code 컬럼을 넣은 뒤 기존 행만 백필했다. 그 이후 만든 개인 홈스쿨은
-- join_code 가 null 이라 시스템 화면에 ------ 만 보이고, 코드로 합류할 수 없다.

create or replace function public.assign_homeschool_join_code()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.join_code is null or btrim(new.join_code) = '' then
    new.join_code := public.gen_join_code();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_homeschools_assign_join_code on public.homeschools;
create trigger trg_homeschools_assign_join_code
before insert on public.homeschools
for each row execute function public.assign_homeschool_join_code();

do $$
declare
  r record;
begin
  for r in
    select id
    from public.homeschools
    where join_code is null or btrim(join_code) = ''
  loop
    update public.homeschools
    set join_code = public.gen_join_code()
    where id = r.id;
  end loop;
end;
$$;
