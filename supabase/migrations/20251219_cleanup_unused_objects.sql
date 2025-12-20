-- Cleanup truly unused objects (as observed in DB) + remove legacy pg_net cron usage

-- =============================================================================
-- 1) Remove legacy cron jobs that call net.http_post (contains hardcoded bearer token)
--    and replace them with in-DB function calls.
-- =============================================================================

-- Unschedule any existing meal reminder jobs (idempotent)
select cron.unschedule(jobid)
from cron.job
where jobname in ('meal-reminder-breakfast', 'meal-reminder-lunch', 'meal-reminder-dinner');

-- Recreate schedules using DB function (no pg_net dependency)
select cron.schedule(
  'meal-reminder-breakfast',
  '0 0 * * *',
  $$ select public.run_meal_reminder('breakfast'); $$
);
select cron.schedule(
  'meal-reminder-lunch',
  '0 4 * * *',
  $$ select public.run_meal_reminder('lunch'); $$
);
select cron.schedule(
  'meal-reminder-dinner',
  '0 12 * * *',
  $$ select public.run_meal_reminder('dinner'); $$
);

-- Now that no jobs depend on pg_net, remove it.
drop extension if exists pg_net;

-- =============================================================================
-- 2) Drop unused NON-UNIQUE indexes (idx_scan=0) that are safe to remove
--    NOTE: We do NOT drop primary keys / unique indexes / constraints.
-- =============================================================================
drop index if exists public.idx_ai_recommendations_session;
drop index if exists public.idx_exercises_created_by;
drop index if exists public.idx_exercises_muscle;
drop index if exists public.idx_support_contacts_user_id;
drop index if exists public.idx_workout_exercises_exercise_id;


