-- Fix infinite recursion in user_profiles RLS policy
-- The previous policy used 'old' and 'new' which are not valid in RLS policies
-- Instead, use a trigger to prevent subscription_tier changes

-- 1) Drop the problematic policy
drop policy if exists "Users can update own profile" on public.user_profiles;

-- 2) Recreate simple update policy (without subscription_tier check in policy)
create policy "Users can update own profile"
  on public.user_profiles
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- 3) Create a trigger to prevent users from changing subscription_tier
create or replace function public.prevent_subscription_tier_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- If subscription_tier is being changed and not by service_role
  if OLD.subscription_tier is distinct from NEW.subscription_tier then
    -- Check if the current role is service_role
    if current_setting('role', true) != 'service_role' then
      -- Revert the change
      NEW.subscription_tier := OLD.subscription_tier;
    end if;
  end if;
  return NEW;
end;
$$;

-- Drop trigger if exists and create new one
drop trigger if exists prevent_subscription_tier_change_trigger on public.user_profiles;

create trigger prevent_subscription_tier_change_trigger
  before update on public.user_profiles
  for each row
  execute function public.prevent_subscription_tier_change();

