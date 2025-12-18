-- User Photos: storage bucket + metadata table + RLS

-- 1) Storage bucket (private)
insert into storage.buckets (id, name, public)
values ('user-photos', 'user-photos', false)
on conflict (id) do nothing;

-- 2) Metadata table
create table if not exists public.user_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  bucket_id text not null default 'user-photos',
  object_path text not null,
  taken_at timestamptz,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_user_photos_user_created_at
  on public.user_photos (user_id, created_at desc);

alter table public.user_photos enable row level security;

drop policy if exists "user_photos_select_own" on public.user_photos;
create policy "user_photos_select_own"
  on public.user_photos
  for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "user_photos_insert_own" on public.user_photos;
create policy "user_photos_insert_own"
  on public.user_photos
  for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "user_photos_delete_own" on public.user_photos;
create policy "user_photos_delete_own"
  on public.user_photos
  for delete
  to authenticated
  using (auth.uid() = user_id);

-- 3) Storage RLS (store objects under "<user_id>/...") 
-- NOTE: storage.objects の RLS はSupabase側で通常有効化済みのため、ここではALTERしない
drop policy if exists "storage_user_photos_select_own" on storage.objects;
create policy "storage_user_photos_select_own"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'user-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "storage_user_photos_insert_own" on storage.objects;
create policy "storage_user_photos_insert_own"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'user-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "storage_user_photos_delete_own" on storage.objects;
create policy "storage_user_photos_delete_own"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'user-photos'
    and auth.uid()::text = (storage.foldername(name))[1]
  );


