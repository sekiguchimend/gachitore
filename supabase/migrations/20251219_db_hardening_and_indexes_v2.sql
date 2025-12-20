-- DB hardening + performance fixes based on Supabase advisors
-- NOTE: pg_net "extension_in_public" lint is not auto-fixable via `ALTER EXTENSION ... SET SCHEMA`
-- (Supabase reports: extension "pg_net" does not support SET SCHEMA). We leave it as-is for now.

-- =============================================================================
-- Indexes for foreign keys (performance)
-- =============================================================================
create index if not exists idx_exercises_created_by on public.exercises(created_by);
create index if not exists idx_support_contacts_user_id on public.support_contacts(user_id);
create index if not exists idx_workout_exercises_exercise_id on public.workout_exercises(exercise_id);

-- =============================================================================
-- RLS policy initplan optimization (performance)
-- Replace auth.uid() with (select auth.uid()) where applicable
-- =============================================================================

-- ai_inbox_messages
alter policy "ai_inbox_select_own" on public.ai_inbox_messages
  using ((select auth.uid()) = user_id);
alter policy "ai_inbox_update_own" on public.ai_inbox_messages
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ai_sessions
alter policy "ai_sessions_select_own" on public.ai_sessions
  using ((select auth.uid()) = user_id);
alter policy "ai_sessions_insert_own" on public.ai_sessions
  with check ((select auth.uid()) = user_id);

-- ai_messages
alter policy "ai_messages_select_own" on public.ai_messages
  using (exists (
    select 1 from public.ai_sessions s
    where s.id = ai_messages.session_id
      and s.user_id = (select auth.uid())
  ));
alter policy "ai_messages_insert_own" on public.ai_messages
  with check (exists (
    select 1 from public.ai_sessions s
    where s.id = ai_messages.session_id
      and s.user_id = (select auth.uid())
  ));

-- ai_recommendations
alter policy "ai_recommendations_select_own" on public.ai_recommendations
  using (exists (
    select 1 from public.ai_sessions s
    where s.id = ai_recommendations.session_id
      and s.user_id = (select auth.uid())
  ));
alter policy "ai_recommendations_insert_own" on public.ai_recommendations
  with check (exists (
    select 1 from public.ai_sessions s
    where s.id = ai_recommendations.session_id
      and s.user_id = (select auth.uid())
  ));
alter policy "ai_recommendations_update_own" on public.ai_recommendations
  using (exists (
    select 1 from public.ai_sessions s
    where s.id = ai_recommendations.session_id
      and s.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.ai_sessions s
    where s.id = ai_recommendations.session_id
      and s.user_id = (select auth.uid())
  ));

-- user_profiles
alter policy "user_profiles_select_own" on public.user_profiles
  using ((select auth.uid()) = user_id);
alter policy "user_profiles_insert_own" on public.user_profiles
  with check ((select auth.uid()) = user_id);
alter policy "user_profiles_update_own" on public.user_profiles
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- body_metrics
alter policy "body_metrics_select_own" on public.body_metrics
  using ((select auth.uid()) = user_id);
alter policy "body_metrics_insert_own" on public.body_metrics
  with check ((select auth.uid()) = user_id);
alter policy "body_metrics_update_own" on public.body_metrics
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy "body_metrics_delete_own" on public.body_metrics
  using ((select auth.uid()) = user_id);

-- workouts
alter policy "workouts_select_own" on public.workouts
  using ((select auth.uid()) = user_id);
alter policy "workouts_insert_own" on public.workouts
  with check ((select auth.uid()) = user_id);
alter policy "workouts_update_own" on public.workouts
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy "workouts_delete_own" on public.workouts
  using ((select auth.uid()) = user_id);

-- workout_exercises
alter policy "workout_exercises_select_own" on public.workout_exercises
  using (exists (
    select 1 from public.workouts w
    where w.id = workout_exercises.workout_id
      and w.user_id = (select auth.uid())
  ));
alter policy "workout_exercises_insert_own" on public.workout_exercises
  with check (exists (
    select 1 from public.workouts w
    where w.id = workout_exercises.workout_id
      and w.user_id = (select auth.uid())
  ));
alter policy "workout_exercises_update_own" on public.workout_exercises
  using (exists (
    select 1 from public.workouts w
    where w.id = workout_exercises.workout_id
      and w.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.workouts w
    where w.id = workout_exercises.workout_id
      and w.user_id = (select auth.uid())
  ));
alter policy "workout_exercises_delete_own" on public.workout_exercises
  using (exists (
    select 1 from public.workouts w
    where w.id = workout_exercises.workout_id
      and w.user_id = (select auth.uid())
  ));

-- workout_sets
alter policy "workout_sets_select_own" on public.workout_sets
  using (exists (
    select 1
    from public.workout_exercises we
    join public.workouts w on w.id = we.workout_id
    where we.id = workout_sets.workout_exercise_id
      and w.user_id = (select auth.uid())
  ));
alter policy "workout_sets_insert_own" on public.workout_sets
  with check (exists (
    select 1
    from public.workout_exercises we
    join public.workouts w on w.id = we.workout_id
    where we.id = workout_sets.workout_exercise_id
      and w.user_id = (select auth.uid())
  ));
alter policy "workout_sets_update_own" on public.workout_sets
  using (exists (
    select 1
    from public.workout_exercises we
    join public.workouts w on w.id = we.workout_id
    where we.id = workout_sets.workout_exercise_id
      and w.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1
    from public.workout_exercises we
    join public.workouts w on w.id = we.workout_id
    where we.id = workout_sets.workout_exercise_id
      and w.user_id = (select auth.uid())
  ));
alter policy "workout_sets_delete_own" on public.workout_sets
  using (exists (
    select 1
    from public.workout_exercises we
    join public.workouts w on w.id = we.workout_id
    where we.id = workout_sets.workout_exercise_id
      and w.user_id = (select auth.uid())
  ));

-- meals
alter policy "meals_select_own" on public.meals
  using ((select auth.uid()) = user_id);
alter policy "meals_insert_own" on public.meals
  with check ((select auth.uid()) = user_id);
alter policy "meals_update_own" on public.meals
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy "meals_delete_own" on public.meals
  using ((select auth.uid()) = user_id);

-- meal_items
alter policy "meal_items_select_own" on public.meal_items
  using (exists (
    select 1 from public.meals m
    where m.id = meal_items.meal_id
      and m.user_id = (select auth.uid())
  ));
alter policy "meal_items_insert_own" on public.meal_items
  with check (exists (
    select 1 from public.meals m
    where m.id = meal_items.meal_id
      and m.user_id = (select auth.uid())
  ));
alter policy "meal_items_update_own" on public.meal_items
  using (exists (
    select 1 from public.meals m
    where m.id = meal_items.meal_id
      and m.user_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.meals m
    where m.id = meal_items.meal_id
      and m.user_id = (select auth.uid())
  ));
alter policy "meal_items_delete_own" on public.meal_items
  using (exists (
    select 1 from public.meals m
    where m.id = meal_items.meal_id
      and m.user_id = (select auth.uid())
  ));

-- nutrition_daily
alter policy "nutrition_daily_select_own" on public.nutrition_daily
  using ((select auth.uid()) = user_id);
alter policy "nutrition_daily_insert_own" on public.nutrition_daily
  with check ((select auth.uid()) = user_id);
alter policy "nutrition_daily_update_own" on public.nutrition_daily
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy "nutrition_daily_delete_own" on public.nutrition_daily
  using ((select auth.uid()) = user_id);

-- user_push_tokens
alter policy "user_push_tokens_select_own" on public.user_push_tokens
  using ((select auth.uid()) = user_id);
alter policy "user_push_tokens_insert_own" on public.user_push_tokens
  with check ((select auth.uid()) = user_id);
alter policy "user_push_tokens_update_own" on public.user_push_tokens
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy "user_push_tokens_delete_own" on public.user_push_tokens
  using ((select auth.uid()) = user_id);

-- user_photos (roles are authenticated)
alter policy "user_photos_select_own" on public.user_photos
  using ((select auth.uid()) = user_id);
alter policy "user_photos_insert_own" on public.user_photos
  with check ((select auth.uid()) = user_id);
alter policy "user_photos_delete_own" on public.user_photos
  using ((select auth.uid()) = user_id);

-- support_contacts
alter policy "support_contacts_select_own" on public.support_contacts
  using (user_id = (select auth.uid()));
alter policy "support_contacts_insert_own" on public.support_contacts
  with check (user_id = (select auth.uid()));

-- exercises
alter policy "exercises_insert_own" on public.exercises
  with check (
    is_system = false
    and created_by = (select auth.uid())
  );
alter policy "exercises_update_own" on public.exercises
  using ((select auth.uid()) = created_by and is_system = false)
  with check ((select auth.uid()) = created_by and is_system = false);
alter policy "exercises_delete_own" on public.exercises
  using ((select auth.uid()) = created_by and is_system = false);
alter policy "exercises_select_system_or_own" on public.exercises
  using (is_system = true or created_by = (select auth.uid()));

-- Remove redundant SELECT policies (keep system_or_own)
drop policy if exists "exercises_select_system" on public.exercises;
drop policy if exists "exercises_select_own" on public.exercises;

-- =============================================================================
-- Security: set stable search_path for functions (search_path mutable warning)
-- =============================================================================
alter function public.enforce_user_photos_limit_100() set search_path = pg_catalog, public;
alter function public.update_updated_at_column() set search_path = pg_catalog, public;
alter function public.update_nutrition_daily() set search_path = pg_catalog, public;
alter function public.handle_new_user() set search_path = pg_catalog, public;
alter function public.calculate_e1rm(p_weight_kg numeric, p_reps integer) set search_path = pg_catalog, public;
alter function public.save_workout(
  p_date date,
  p_start_time timestamp with time zone,
  p_end_time timestamp with time zone,
  p_perceived_fatigue integer,
  p_note text,
  p_exercises jsonb
) set search_path = pg_catalog, public;
alter function public.get_dashboard_today(p_date date) set search_path = pg_catalog, public;


