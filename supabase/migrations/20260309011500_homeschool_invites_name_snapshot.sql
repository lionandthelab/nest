-- Ensure invite recipients can always read homeschool name even when homeschools join is blocked by RLS.

alter table public.homeschool_invites
add column if not exists homeschool_name text;

create or replace function public.set_homeschool_invite_name()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  select h.name
    into new.homeschool_name
  from public.homeschools h
  where h.id = new.homeschool_id;

  new.homeschool_name := coalesce(nullif(trim(new.homeschool_name), ''), 'Unknown Homeschool');
  return new;
end;
$$;

drop trigger if exists trg_homeschool_invites_set_name on public.homeschool_invites;
create trigger trg_homeschool_invites_set_name
before insert or update of homeschool_id on public.homeschool_invites
for each row execute function public.set_homeschool_invite_name();

create or replace function public.refresh_homeschool_invite_names()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.name is distinct from old.name then
    update public.homeschool_invites hi
    set homeschool_name = new.name
    where hi.homeschool_id = new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_homeschools_refresh_invite_names on public.homeschools;
create trigger trg_homeschools_refresh_invite_names
after update of name on public.homeschools
for each row execute function public.refresh_homeschool_invite_names();

update public.homeschool_invites hi
set homeschool_name = h.name
from public.homeschools h
where h.id = hi.homeschool_id
  and (hi.homeschool_name is null or trim(hi.homeschool_name) = '');

update public.homeschool_invites
set homeschool_name = 'Unknown Homeschool'
where homeschool_name is null or trim(homeschool_name) = '';
