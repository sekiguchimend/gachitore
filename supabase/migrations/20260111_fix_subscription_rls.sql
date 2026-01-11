-- Fix RLS policies to check user_subscriptions instead of user_profiles.subscription_tier
-- This prevents users from bypassing subscription checks by manually updating user_profiles

-- Drop old policy
drop policy if exists "Premium users can manage blocks" on public.user_blocks;

-- Create new policy that checks actual subscription status
create policy "Premium users can manage blocks"
  on public.user_blocks
  for all
  to authenticated
  using (
    auth.uid() = blocker_user_id
    and exists (
      select 1 from public.user_subscriptions
      where user_id = auth.uid()
        and subscription_tier = 'premium'
        and status = 'active'
        and expires_at > now()
    )
  )
  with check (
    auth.uid() = blocker_user_id
    and exists (
      select 1 from public.user_subscriptions
      where user_id = auth.uid()
        and subscription_tier = 'premium'
        and status = 'active'
        and expires_at > now()
    )
  );

-- Also ensure user_profiles.subscription_tier cannot be updated by users
-- Remove update permission on subscription_tier column if it exists
drop policy if exists "Users can update own profile" on public.user_profiles;

create policy "Users can update own profile"
  on public.user_profiles
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    -- Prevent users from updating subscription_tier (must remain unchanged)
    and old.subscription_tier = new.subscription_tier
  );

-- Only service_role can update subscription_tier
drop policy if exists "Service role can manage profiles" on public.user_profiles;

create policy "Service role can manage profiles"
  on public.user_profiles
  for all
  to service_role
  using (true)
  with check (true);
