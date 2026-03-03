-- Homeschool invite workflow: admin email invite + invited user acceptance RPC

do $$
begin
  if not exists (select 1 from pg_type where typname = 'invite_status') then
    create type public.invite_status as enum ('PENDING', 'ACCEPTED', 'CANCELED', 'EXPIRED');
  end if;
end
$$;

create table if not exists public.homeschool_invites (
  id uuid primary key default gen_random_uuid(),
  homeschool_id uuid not null references public.homeschools(id) on delete cascade,
  invite_email text not null,
  role public.membership_role not null,
  invite_token text not null unique default (
    substring(
      replace(gen_random_uuid()::text, '-', '') ||
      replace(gen_random_uuid()::text, '-', '')
      from 1 for 48
    )
  ),
  status public.invite_status not null default 'PENDING',
  invited_by_user_id uuid not null references auth.users(id) on delete restrict,
  accepted_by_user_id uuid references auth.users(id) on delete set null,
  expires_at timestamptz not null default (now() + interval '14 days'),
  accepted_at timestamptz,
  canceled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (char_length(trim(invite_email)) >= 5)
);

create index if not exists idx_homeschool_invites_school_status_created
  on public.homeschool_invites (homeschool_id, status, created_at desc);

create index if not exists idx_homeschool_invites_email_status_created
  on public.homeschool_invites (lower(invite_email), status, created_at desc);

create unique index if not exists uq_homeschool_invites_pending_email_role
  on public.homeschool_invites (homeschool_id, lower(invite_email), role)
  where status = 'PENDING';

drop trigger if exists trg_homeschool_invites_updated_at on public.homeschool_invites;
create trigger trg_homeschool_invites_updated_at
before update on public.homeschool_invites
for each row execute function public.set_updated_at();

create or replace function public.accept_homeschool_invite(p_invite_token text)
returns table (
  homeschool_id uuid,
  role public.membership_role,
  status public.invite_status
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_email text := lower(trim(coalesce(auth.jwt() ->> 'email', '')));
  v_invite public.homeschool_invites%rowtype;
  v_token text := trim(coalesce(p_invite_token, ''));
begin
  if v_user_id is null then
    raise exception using errcode = '42501', message = 'AUTH_REQUIRED';
  end if;

  if v_email = '' then
    raise exception using errcode = '22023', message = 'USER_EMAIL_NOT_FOUND';
  end if;

  if v_token = '' then
    raise exception using errcode = '22023', message = 'INVITE_TOKEN_REQUIRED';
  end if;

  select hi.*
    into v_invite
  from public.homeschool_invites hi
  where hi.invite_token = v_token
  for update;

  if not found then
    raise exception using errcode = '22023', message = 'INVITE_NOT_FOUND';
  end if;

  if v_invite.status <> 'PENDING' then
    raise exception using errcode = '22023', message = 'INVITE_NOT_PENDING';
  end if;

  if v_invite.expires_at <= now() then
    update public.homeschool_invites
    set status = 'EXPIRED',
        updated_at = now()
    where id = v_invite.id;

    raise exception using errcode = '22023', message = 'INVITE_EXPIRED';
  end if;

  if lower(v_invite.invite_email) <> v_email then
    raise exception using errcode = '42501', message = 'INVITE_EMAIL_MISMATCH';
  end if;

  insert into public.homeschool_memberships (homeschool_id, user_id, role, status)
  values (v_invite.homeschool_id, v_user_id, v_invite.role, 'ACTIVE')
  on conflict (homeschool_id, user_id, role) do update
  set status = 'ACTIVE',
      updated_at = now();

  update public.homeschool_invites
  set status = 'ACCEPTED',
      accepted_by_user_id = v_user_id,
      accepted_at = now(),
      updated_at = now()
  where id = v_invite.id;

  return query
  select
    v_invite.homeschool_id,
    v_invite.role,
    'ACCEPTED'::public.invite_status;
end;
$$;

grant execute on function public.accept_homeschool_invite(text) to authenticated;

alter table public.homeschool_invites enable row level security;

drop policy if exists homeschool_invites_select_admin_or_invited on public.homeschool_invites;
create policy homeschool_invites_select_admin_or_invited on public.homeschool_invites
for select using (
  public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN', 'STAFF']::public.membership_role[]
  )
  or lower(invite_email) = lower(coalesce(auth.jwt() ->> 'email', ''))
);

drop policy if exists homeschool_invites_insert_admin on public.homeschool_invites;
create policy homeschool_invites_insert_admin on public.homeschool_invites
for insert with check (
  invited_by_user_id = auth.uid()
  and status = 'PENDING'
  and public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN']::public.membership_role[]
  )
);

drop policy if exists homeschool_invites_update_admin on public.homeschool_invites;
create policy homeschool_invites_update_admin on public.homeschool_invites
for update using (
  public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN']::public.membership_role[]
  )
)
with check (
  public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN']::public.membership_role[]
  )
);

drop policy if exists homeschool_invites_delete_admin on public.homeschool_invites;
create policy homeschool_invites_delete_admin on public.homeschool_invites
for delete using (
  public.has_homeschool_role(
    homeschool_id,
    array['HOMESCHOOL_ADMIN']::public.membership_role[]
  )
);
