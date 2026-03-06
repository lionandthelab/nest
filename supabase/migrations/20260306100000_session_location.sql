-- Add location column to class_sessions
alter table public.class_sessions
  add column if not exists location text;

-- Comment
comment on column public.class_sessions.location is 'Physical room/space name for this session';
