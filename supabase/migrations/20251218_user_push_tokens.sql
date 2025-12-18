-- User push tokens for FCM (Firebase Cloud Messaging)
-- Stores device tokens per user to enable push notifications.

create table if not exists public.user_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  token text not null,
  platform text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists user_push_tokens_user_token_key
  on public.user_push_tokens (user_id, token);

alter table public.user_push_tokens enable row level security;

-- Users can manage their own tokens
drop policy if exists "user_push_tokens_select_own" on public.user_push_tokens;
create policy "user_push_tokens_select_own"
  on public.user_push_tokens
  for select
  using (auth.uid() = user_id);

drop policy if exists "user_push_tokens_insert_own" on public.user_push_tokens;
create policy "user_push_tokens_insert_own"
  on public.user_push_tokens
  for insert
  with check (auth.uid() = user_id);

drop policy if exists "user_push_tokens_update_own" on public.user_push_tokens;
create policy "user_push_tokens_update_own"
  on public.user_push_tokens
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "user_push_tokens_delete_own" on public.user_push_tokens;
create policy "user_push_tokens_delete_own"
  on public.user_push_tokens
  for delete
  using (auth.uid() = user_id);


