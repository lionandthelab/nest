-- Migration: Switch media storage from Google Drive to Supabase Storage
-- 1. Create public storage bucket 'media'
-- 2. Add storage_path column to media_assets
-- 3. Relax drive_file_id NOT NULL constraint for new uploads

-- ── 1. Storage bucket ──
insert into storage.buckets (id, name, public)
values ('media', 'media', true)
on conflict (id) do nothing;

-- Allow authenticated users to upload
create policy "media_insert_authenticated"
  on storage.objects for insert
  with check (
    bucket_id = 'media'
    and auth.role() = 'authenticated'
  );

-- Allow anyone to read (public bucket)
create policy "media_select_public"
  on storage.objects for select
  using (bucket_id = 'media');

-- Allow authenticated users to delete their uploads
create policy "media_delete_authenticated"
  on storage.objects for delete
  using (
    bucket_id = 'media'
    and auth.role() = 'authenticated'
  );

-- ── 2. Schema changes ──
-- Add storage_path column
alter table public.media_assets
  add column if not exists storage_path text;

-- Relax drive_file_id: allow NULL for new storage-based uploads
alter table public.media_assets
  alter column drive_file_id drop not null;

-- Make unique constraint partial (only for non-null values)
alter table public.media_assets
  drop constraint if exists media_assets_drive_file_id_key;

create unique index if not exists media_assets_drive_file_id_unique
  on public.media_assets (drive_file_id)
  where drive_file_id is not null;

-- Also relax upload_session_id NOT NULL + UNIQUE since storage uploads
-- can optionally skip the session tracking
alter table public.media_assets
  alter column upload_session_id drop not null;

alter table public.media_assets
  drop constraint if exists media_assets_upload_session_id_key;

create unique index if not exists media_assets_upload_session_id_unique
  on public.media_assets (upload_session_id)
  where upload_session_id is not null;
