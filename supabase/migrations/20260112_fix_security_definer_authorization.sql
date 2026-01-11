-- SECURITY FIX: Add authorization checks to SECURITY DEFINER functions
-- Issue: These functions allow any authenticated user to query any user's subscription info
-- Fix: Only allow querying own subscription tier or service role access

-- 1) Fix get_user_subscription_tier to require authorization
create or replace function public.get_user_subscription_tier(target_user_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  tier text;
begin
  -- SECURITY: Only allow querying own tier or service role access
  -- This prevents enumeration of premium users and privacy violations
  if auth.uid() != target_user_id and current_setting('role', true) != 'service_role' then
    raise exception 'Unauthorized: Cannot access subscription tier for other users';
  end if;

  select subscription_tier into tier
  from public.user_profiles
  where user_id = target_user_id;

  return coalesce(tier, 'free');
end;
$$;

comment on function public.get_user_subscription_tier(uuid) is
  'Returns subscription tier for a user. Authorization: Only own tier or service role.';


-- 2) Fix has_active_subscription to require authorization
create or replace function public.has_active_subscription(target_user_id uuid, required_tier text)
returns boolean
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  current_tier text;
begin
  -- SECURITY: Only allow checking own subscription or service role access
  if auth.uid() != target_user_id and current_setting('role', true) != 'service_role' then
    raise exception 'Unauthorized: Cannot check subscription status for other users';
  end if;

  select subscription_tier into current_tier
  from public.user_profiles
  where user_id = target_user_id;

  if required_tier = 'basic' then
    return current_tier in ('basic', 'premium');
  elsif required_tier = 'premium' then
    return current_tier = 'premium';
  else
    return true;  -- free tier
  end if;
end;
$$;

comment on function public.has_active_subscription(uuid, text) is
  'Checks if user has active subscription at required tier. Authorization: Only own subscription or service role.';
