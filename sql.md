-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.ai_inbox_messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  date date NOT NULL,
  kind text NOT NULL,
  meal_type text NOT NULL DEFAULT ''::text CHECK (meal_type = ANY (ARRAY[''::text, 'breakfast'::text, 'lunch'::text, 'dinner'::text])),
  content text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  consumed_at timestamp with time zone,
  CONSTRAINT ai_inbox_messages_pkey PRIMARY KEY (id),
  CONSTRAINT ai_inbox_messages_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.ai_messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL,
  role text NOT NULL CHECK (role = ANY (ARRAY['user'::text, 'assistant'::text, 'system'::text])),
  content text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_messages_pkey PRIMARY KEY (id),
  CONSTRAINT ai_messages_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.ai_sessions(id)
);
CREATE TABLE public.ai_recommendations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL,
  kind text NOT NULL,
  payload jsonb NOT NULL,
  is_applied boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_recommendations_pkey PRIMARY KEY (id),
  CONSTRAINT ai_recommendations_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.ai_sessions(id)
);
CREATE TABLE public.ai_sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  intent text NOT NULL,
  state_version text NOT NULL DEFAULT 'v1'::text,
  model text NOT NULL DEFAULT 'gemini-1.5-flash'::text,
  input_summary jsonb,
  safety_flags jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT ai_sessions_pkey PRIMARY KEY (id),
  CONSTRAINT ai_sessions_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.body_metrics (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  date date NOT NULL,
  weight_kg numeric CHECK (weight_kg IS NULL OR weight_kg >= 20::numeric AND weight_kg <= 500::numeric),
  bodyfat_pct numeric CHECK (bodyfat_pct IS NULL OR bodyfat_pct >= 1::numeric AND bodyfat_pct <= 70::numeric),
  sleep_hours numeric CHECK (sleep_hours IS NULL OR sleep_hours >= 0::numeric AND sleep_hours <= 24::numeric),
  steps integer CHECK (steps IS NULL OR steps >= 0),
  note text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT body_metrics_pkey PRIMARY KEY (id),
  CONSTRAINT body_metrics_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.comment_likes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  comment_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT comment_likes_pkey PRIMARY KEY (id),
  CONSTRAINT comment_likes_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.post_comments(id),
  CONSTRAINT comment_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.exercises (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  name_en text,
  primary_muscle text NOT NULL,
  secondary_muscles ARRAY NOT NULL DEFAULT ARRAY[]::text[],
  equipment text,
  is_system boolean NOT NULL DEFAULT false,
  created_by uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT exercises_pkey PRIMARY KEY (id),
  CONSTRAINT exercises_created_by_fkey FOREIGN KEY (created_by) REFERENCES auth.users(id)
);
CREATE TABLE public.meal_items (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  meal_id uuid NOT NULL,
  name text NOT NULL,
  quantity numeric NOT NULL DEFAULT 1,
  unit text NOT NULL DEFAULT 'serving'::text,
  calories integer CHECK (calories IS NULL OR calories >= 0),
  protein_g numeric CHECK (protein_g IS NULL OR protein_g >= 0::numeric),
  fat_g numeric CHECK (fat_g IS NULL OR fat_g >= 0::numeric),
  carbs_g numeric CHECK (carbs_g IS NULL OR carbs_g >= 0::numeric),
  fiber_g numeric CHECK (fiber_g IS NULL OR fiber_g >= 0::numeric),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT meal_items_pkey PRIMARY KEY (id),
  CONSTRAINT meal_items_meal_id_fkey FOREIGN KEY (meal_id) REFERENCES public.meals(id)
);
CREATE TABLE public.meals (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  date date NOT NULL,
  time time without time zone,
  meal_type text NOT NULL CHECK (meal_type = ANY (ARRAY['breakfast'::text, 'lunch'::text, 'dinner'::text, 'snack'::text, 'pre_workout'::text, 'post_workout'::text])),
  meal_index integer NOT NULL DEFAULT 1 CHECK (meal_index >= 1 AND meal_index <= 10),
  note text,
  photo_url text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT meals_pkey PRIMARY KEY (id),
  CONSTRAINT meals_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.nutrition_daily (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  date date NOT NULL,
  calories integer NOT NULL DEFAULT 0,
  protein_g numeric NOT NULL DEFAULT 0,
  fat_g numeric NOT NULL DEFAULT 0,
  carbs_g numeric NOT NULL DEFAULT 0,
  fiber_g numeric NOT NULL DEFAULT 0,
  meals_logged integer NOT NULL DEFAULT 0,
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT nutrition_daily_pkey PRIMARY KEY (id),
  CONSTRAINT nutrition_daily_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.post_comments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL,
  user_id uuid NOT NULL,
  content text NOT NULL CHECK (char_length(content) <= 500),
  reply_to_user_id uuid,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT post_comments_pkey PRIMARY KEY (id),
  CONSTRAINT post_comments_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id),
  CONSTRAINT post_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT post_comments_reply_to_user_id_fkey FOREIGN KEY (reply_to_user_id) REFERENCES auth.users(id),
  CONSTRAINT post_comments_user_id_user_profiles_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(user_id),
  CONSTRAINT post_comments_reply_to_user_id_user_profiles_fkey FOREIGN KEY (reply_to_user_id) REFERENCES public.user_profiles(user_id)
);
CREATE TABLE public.post_likes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  post_id uuid NOT NULL,
  user_id uuid NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT post_likes_pkey PRIMARY KEY (id),
  CONSTRAINT post_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT post_likes_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id)
);
CREATE TABLE public.posts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  content text NOT NULL CHECK (char_length(content) <= 1000),
  image_path text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT posts_pkey PRIMARY KEY (id),
  CONSTRAINT posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id),
  CONSTRAINT posts_user_id_user_profiles_fkey FOREIGN KEY (user_id) REFERENCES public.user_profiles(user_id)
);
CREATE TABLE public.support_contacts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  email text,
  subject text NOT NULL,
  message text NOT NULL,
  platform text,
  app_version text,
  device_info jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT support_contacts_pkey PRIMARY KEY (id),
  CONSTRAINT support_contacts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_profiles (
  user_id uuid NOT NULL,
  display_name text NOT NULL,
  sex text CHECK (sex IS NULL OR (sex = ANY (ARRAY['male'::text, 'female'::text, 'other'::text]))),
  birth_year integer CHECK (birth_year IS NULL OR birth_year >= 1900 AND birth_year <= 2100),
  height_cm integer CHECK (height_cm IS NULL OR height_cm >= 50 AND height_cm <= 300),
  training_level text NOT NULL DEFAULT 'beginner'::text CHECK (training_level = ANY (ARRAY['beginner'::text, 'intermediate'::text, 'advanced'::text])),
  goal text NOT NULL DEFAULT 'health'::text CHECK (goal = ANY (ARRAY['hypertrophy'::text, 'cut'::text, 'health'::text, 'strength'::text])),
  environment jsonb NOT NULL DEFAULT '{}'::jsonb,
  constraints jsonb NOT NULL DEFAULT '[]'::jsonb,
  meals_per_day integer NOT NULL DEFAULT 3 CHECK (meals_per_day >= 1 AND meals_per_day <= 10),
  onboarding_completed boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  target_calories integer DEFAULT 2400 CHECK (target_calories IS NULL OR target_calories >= 500 AND target_calories <= 10000),
  target_protein_g numeric DEFAULT 150 CHECK (target_protein_g IS NULL OR target_protein_g >= 0::numeric AND target_protein_g <= 1000::numeric),
  target_fat_g numeric DEFAULT 80 CHECK (target_fat_g IS NULL OR target_fat_g >= 0::numeric AND target_fat_g <= 500::numeric),
  target_carbs_g numeric DEFAULT 250 CHECK (target_carbs_g IS NULL OR target_carbs_g >= 0::numeric AND target_carbs_g <= 1000::numeric),
  avatar_path text,
  CONSTRAINT user_profiles_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_profiles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.user_push_tokens (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  token text NOT NULL,
  platform text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT user_push_tokens_pkey PRIMARY KEY (id),
  CONSTRAINT user_push_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);
CREATE TABLE public.workout_exercises (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  workout_id uuid NOT NULL,
  exercise_id uuid,
  custom_exercise_name text,
  muscle_tag text NOT NULL,
  exercise_order integer NOT NULL DEFAULT 0,
  note text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT workout_exercises_pkey PRIMARY KEY (id),
  CONSTRAINT workout_exercises_workout_id_fkey FOREIGN KEY (workout_id) REFERENCES public.workouts(id),
  CONSTRAINT workout_exercises_exercise_id_fkey FOREIGN KEY (exercise_id) REFERENCES public.exercises(id)
);
CREATE TABLE public.workout_sets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  workout_exercise_id uuid NOT NULL,
  set_index integer NOT NULL CHECK (set_index >= 1),
  weight_kg numeric CHECK (weight_kg IS NULL OR weight_kg >= 0::numeric),
  reps integer CHECK (reps IS NULL OR reps >= 0),
  rpe numeric CHECK (rpe IS NULL OR rpe >= 1::numeric AND rpe <= 10::numeric),
  rest_sec integer CHECK (rest_sec IS NULL OR rest_sec >= 0),
  tempo text,
  is_warmup boolean NOT NULL DEFAULT false,
  is_dropset boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT workout_sets_pkey PRIMARY KEY (id),
  CONSTRAINT workout_sets_workout_exercise_id_fkey FOREIGN KEY (workout_exercise_id) REFERENCES public.workout_exercises(id)
);
CREATE TABLE public.workouts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  date date NOT NULL,
  start_time timestamp with time zone,
  end_time timestamp with time zone,
  perceived_fatigue integer CHECK (perceived_fatigue IS NULL OR perceived_fatigue >= 1 AND perceived_fatigue <= 5),
  note text,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  total_volume numeric DEFAULT 0,
  CONSTRAINT workouts_pkey PRIMARY KEY (id),
  CONSTRAINT workouts_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);