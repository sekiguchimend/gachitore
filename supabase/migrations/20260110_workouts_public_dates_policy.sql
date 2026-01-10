-- Allow authenticated users to view workout dates of any user (for profile grass graph)
-- This policy allows SELECT only on the date column for any user's workouts

-- Drop the existing restrictive policy and recreate with broader access
drop policy if exists "workouts_select_own" on public.workouts;

-- Users can select their own workouts (full access)
create policy "workouts_select_own"
  on public.workouts
  for select
  using ((select auth.uid()) = user_id);

-- Any authenticated user can view workout dates (for public profile)
create policy "workouts_select_dates_public"
  on public.workouts
  for select
  using (auth.role() = 'authenticated');
