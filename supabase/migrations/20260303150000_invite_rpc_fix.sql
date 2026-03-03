-- Fix accept_homeschool_invite output variable collision with RLS policy columns

drop function if exists public.accept_homeschool_invite(text);

create function public.accept_homeschool_invite(p_invite_token text)
returns table (
  result_homeschool_id uuid,
  result_role public.membership_role,
  result_status public.invite_status
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
