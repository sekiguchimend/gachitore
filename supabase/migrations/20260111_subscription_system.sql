-- Migration: Subscription System (IAP) - aligned with docs/subscription_implementation_flow.md
-- Created: 2026-01-11
-- Description: Create tables/columns/RLS for subscription tiers and blocking, plus helper functions.

-- 1) user_subscriptions
create table if not exists public.user_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subscription_tier text not null check (subscription_tier in ('free', 'basic', 'premium')),
  platform text not null check (platform in ('android', 'ios')),
  product_id text not null,
  purchase_token text,
  transaction_id text,
  starts_at timestamptz not null default now(),
  expires_at timestamptz not null,
  auto_renewing boolean default true,
  status text not null check (status in ('active', 'cancelled', 'expired', 'pending')) default 'active',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id)
);

create index if not exists idx_user_subscriptions_user_id on public.user_subscriptions(user_id);
create index if not exists idx_user_subscriptions_expires_at on public.user_subscriptions(expires_at);
create index if not exists idx_user_subscriptions_status on public.user_subscriptions(status);

alter table public.user_subscriptions enable row level security;

drop policy if exists "Users can view own subscription" on public.user_subscriptions;
drop policy if exists "Service role can manage subscriptions" on public.user_subscriptions;

create policy "Users can view own subscription"
  on public.user_subscriptions
  for select
  to authenticated
  using (auth.uid() = user_id);

create policy "Service role can manage subscriptions"
  on public.user_subscriptions
  for all
  to service_role
  using (true)
  with check (true);


-- 2) user_profiles columns for subscription
alter table public.user_profiles
  add column if not exists sns_links jsonb not null default '[]'::jsonb,
  add column if not exists is_online boolean not null default false,
  add column if not exists last_seen_at timestamptz,
  add column if not exists subscription_tier text not null default 'free';

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'user_profiles_subscription_tier_check'
  ) then
    alter table public.user_profiles
      add constraint user_profiles_subscription_tier_check
      check (subscription_tier in ('free', 'basic', 'premium'));
  end if;
end
$$;

create index if not exists idx_user_profiles_subscription_tier on public.user_profiles(subscription_tier);
create index if not exists idx_user_profiles_is_online on public.user_profiles(is_online);


-- 3) user_blocks
create table if not exists public.user_blocks (
  id uuid primary key default gen_random_uuid(),
  blocker_user_id uuid not null references auth.users(id) on delete cascade,
  blocked_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now(),
  unique(blocker_user_id, blocked_user_id),
  constraint user_blocks_not_self check (blocker_user_id <> blocked_user_id)
);

create index if not exists idx_user_blocks_blocker on public.user_blocks(blocker_user_id);
create index if not exists idx_user_blocks_blocked on public.user_blocks(blocked_user_id);

alter table public.user_blocks enable row level security;

drop policy if exists "Users can view own blocks" on public.user_blocks;
drop policy if exists "Premium users can manage blocks" on public.user_blocks;

create policy "Users can view own blocks"
  on public.user_blocks
  for select
  to authenticated
  using (auth.uid() = blocker_user_id);

create policy "Premium users can manage blocks"
  on public.user_blocks
  for all
  to authenticated
  using (
    auth.uid() = blocker_user_id
    and exists (
      select 1 from public.user_profiles
      where user_id = auth.uid()
        and subscription_tier = 'premium'
    )
  )
  with check (
    auth.uid() = blocker_user_id
    and exists (
      select 1 from public.user_profiles
      where user_id = auth.uid()
        and subscription_tier = 'premium'
    )
  );


-- 4) posts select policy update (non-blocked)
drop policy if exists posts_select_all on public.posts;
drop policy if exists "Posts are viewable by non-blocked users" on public.posts;

create policy "Posts are viewable by non-blocked users"
  on public.posts
  for select
  to authenticated
  using (
    auth.uid() = user_id
    or not exists (
      select 1
      from public.user_blocks ub
      where ub.blocker_user_id = posts.user_id
        and ub.blocked_user_id = auth.uid()
    )
  );


-- 5) helper functions
create or replace function public.get_user_subscription_tier(target_user_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  tier text;
begin
  select subscription_tier into tier
  from public.user_profiles
  where user_id = target_user_id;

  return coalesce(tier, 'free');
end;
$$;

create or replace function public.has_active_subscription(target_user_id uuid, required_tier text)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_tier text;
begin
  select subscription_tier into current_tier
  from public.user_profiles
  where user_id = target_user_id;

  if required_tier = 'basic' then
    return current_tier in ('basic', 'premium');
  elsif required_tier = 'premium' then
    return current_tier = 'premium';
  else
    return true;
  end if;
end;
$$;
