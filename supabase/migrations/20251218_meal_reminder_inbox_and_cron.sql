-- Enable required extensions for scheduling Edge Functions
create extension if not exists pg_cron;
create extension if not exists pg_net;

-- -----------------------------------------------------------------------------
-- Inbox table for bot messages (shown in app chat)
-- -----------------------------------------------------------------------------
create table if not exists public.ai_inbox_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date date not null,
  kind text not null,
  meal_type text not null default ''::text,
  content text not null,
  created_at timestamptz not null default now(),
  consumed_at timestamptz,

  constraint ai_inbox_messages_meal_type_check
    check (meal_type in ('', 'breakfast', 'lunch', 'dinner')),

  constraint ai_inbox_messages_unique
    unique (user_id, date, kind, meal_type)
);

comment on table public.ai_inbox_messages is 'アプリ内チャットに表示するボット通知（例: 食事リマインド）';

alter table public.ai_inbox_messages enable row level security;

drop policy if exists "ai_inbox_select_own" on public.ai_inbox_messages;
drop policy if exists "ai_inbox_update_own" on public.ai_inbox_messages;

create policy "ai_inbox_select_own" on public.ai_inbox_messages
  for select
  using (auth.uid() = user_id);

create policy "ai_inbox_update_own" on public.ai_inbox_messages
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists idx_ai_inbox_messages_user_consumed_created
  on public.ai_inbox_messages (user_id, consumed_at, created_at);

-- -----------------------------------------------------------------------------
-- Cron jobs (DB timezone is typically UTC on Supabase)
-- 09:00 JST = 00:00 UTC
-- 13:00 JST = 04:00 UTC
-- 21:00 JST = 12:00 UTC
--
-- NOTE:
-- - Cron configuration is moved to a later migration to avoid embedding any tokens/keys in git.
-- -----------------------------------------------------------------------------

