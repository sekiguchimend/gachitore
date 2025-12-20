-- Support contacts table + RLS
create table if not exists public.support_contacts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  email text,
  subject text not null,
  message text not null,
  platform text,
  app_version text,
  device_info jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.support_contacts enable row level security;

-- Users can insert their own support contact rows
drop policy if exists "support_contacts_insert_own" on public.support_contacts;
create policy "support_contacts_insert_own"
  on public.support_contacts
  for insert
  with check (user_id = auth.uid());

-- (Optional) allow users to read their own sent contacts
drop policy if exists "support_contacts_select_own" on public.support_contacts;
create policy "support_contacts_select_own"
  on public.support_contacts
  for select
  using (user_id = auth.uid());

-- Allow users to insert their own custom exercises
-- (system exercises are created_by NULL, is_system=true)
alter table public.exercises enable row level security;

drop policy if exists "exercises_insert_own" on public.exercises;
create policy "exercises_insert_own"
  on public.exercises
  for insert
  with check (
    is_system = false
    and created_by = auth.uid()
  );

-- Ensure users can select system exercises and their own custom exercises
drop policy if exists "exercises_select_system_or_own" on public.exercises;
create policy "exercises_select_system_or_own"
  on public.exercises
  for select
  using (
    is_system = true
    or created_by = auth.uid()
  );


