-- SECURITY FIX: Make subscription tier protection explicit with errors instead of silent reversion
-- Issue: The trigger silently reverts subscription_tier changes, causing inconsistent state
-- Fix: Raise explicit error when unauthorized tier change is attempted

create or replace function public.prevent_subscription_tier_change()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  -- SECURITY: Subscription tier can only be modified via purchase verification API
  -- This prevents privilege escalation and maintains payment integrity
  if OLD.subscription_tier is distinct from NEW.subscription_tier then
    if current_setting('role', true) != 'service_role' then
      raise exception 'Subscription tier can only be modified via purchase verification API'
        using hint = 'Use POST /v1/subscriptions/verify to upgrade subscription',
              errcode = '42501';  -- insufficient_privilege
    end if;
  end if;
  return NEW;
end;
$$;

comment on function public.prevent_subscription_tier_change() is
  'Prevents unauthorized subscription_tier modifications. Only service_role can update.';
