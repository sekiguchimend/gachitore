# Database Schema (Supabase PostgreSQL)

## Overview

筋トレ/食事/体重/睡眠管理アプリのデータベーススキーマ。
Supabase Auth + PostgreSQL + RLS を使用。

---

## 1. Extensions

```sql
-- Supabaseではデフォルトで有効だが念のため
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
```

---

## 2. Tables

### 2.1 user_profiles（ユーザープロフィール）

```sql
CREATE TABLE public.user_profiles (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    sex TEXT CHECK (sex IS NULL OR sex IN ('male', 'female', 'other')),
    birth_year INTEGER CHECK (birth_year IS NULL OR (birth_year >= 1900 AND birth_year <= 2100)),
    height_cm INTEGER CHECK (height_cm IS NULL OR (height_cm >= 50 AND height_cm <= 300)),
    training_level TEXT NOT NULL DEFAULT 'beginner'
        CHECK (training_level IN ('beginner', 'intermediate', 'advanced')),
    goal TEXT NOT NULL DEFAULT 'health'
        CHECK (goal IN ('hypertrophy', 'cut', 'health', 'strength')),
    environment JSONB NOT NULL DEFAULT '{}'::jsonb,
    constraints JSONB NOT NULL DEFAULT '[]'::jsonb,
    meals_per_day INTEGER NOT NULL DEFAULT 3 CHECK (meals_per_day >= 1 AND meals_per_day <= 10),
    onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.user_profiles IS 'ユーザーの基本プロフィール情報';
COMMENT ON COLUMN public.user_profiles.environment IS '例: {"gym": true, "home": true, "equipment": ["dumbbell", "bench", "barbell"]}';
COMMENT ON COLUMN public.user_profiles.constraints IS '例: [{"part": "shoulder", "severity": "mild", "note": "..."}]';
```

### 2.2 body_metrics（体重・体脂肪等の日次記録）

```sql
CREATE TABLE public.body_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    weight_kg NUMERIC(5,2) CHECK (weight_kg IS NULL OR (weight_kg >= 20 AND weight_kg <= 500)),
    bodyfat_pct NUMERIC(5,2) CHECK (bodyfat_pct IS NULL OR (bodyfat_pct >= 1 AND bodyfat_pct <= 70)),
    sleep_hours NUMERIC(4,2) CHECK (sleep_hours IS NULL OR (sleep_hours >= 0 AND sleep_hours <= 24)),
    steps INTEGER CHECK (steps IS NULL OR steps >= 0),
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT body_metrics_user_date_unique UNIQUE(user_id, date)
);

COMMENT ON TABLE public.body_metrics IS '日次の体重・体脂肪・睡眠・歩数記録';
```

### 2.3 exercises（種目マスタ）

```sql
CREATE TABLE public.exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    name_en TEXT,
    primary_muscle TEXT NOT NULL,
    secondary_muscles TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    equipment TEXT,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- システム種目の重複防止（created_by IS NULL の場合）
CREATE UNIQUE INDEX idx_exercises_system_name
    ON public.exercises(name)
    WHERE is_system = TRUE;

-- ユーザー定義種目の重複防止（同一ユーザー内）
CREATE UNIQUE INDEX idx_exercises_user_name
    ON public.exercises(name, created_by)
    WHERE is_system = FALSE AND created_by IS NOT NULL;

COMMENT ON TABLE public.exercises IS '筋トレ種目マスタ（システム定義 + ユーザー定義）';
COMMENT ON COLUMN public.exercises.primary_muscle IS 'chest, back, shoulder, biceps, triceps, forearm, abs, quadriceps, hamstrings, glutes, calves';
COMMENT ON COLUMN public.exercises.equipment IS 'barbell, dumbbell, machine, cable, bodyweight, kettlebell, band';
```

### 2.4 workouts（トレーニングセッション）

```sql
CREATE TABLE public.workouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    perceived_fatigue INTEGER CHECK (perceived_fatigue IS NULL OR (perceived_fatigue >= 1 AND perceived_fatigue <= 5)),
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.workouts IS 'トレーニングセッション（1回のトレーニング）';
COMMENT ON COLUMN public.workouts.perceived_fatigue IS '体感疲労度 1:軽い 2:やや軽い 3:普通 4:きつい 5:非常にきつい';
```

### 2.5 workout_exercises（セッション内の種目）

```sql
CREATE TABLE public.workout_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_id UUID NOT NULL REFERENCES public.workouts(id) ON DELETE CASCADE,
    exercise_id UUID REFERENCES public.exercises(id) ON DELETE SET NULL,
    custom_exercise_name TEXT,
    muscle_tag TEXT NOT NULL,
    exercise_order INTEGER NOT NULL DEFAULT 0,
    note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT workout_exercises_has_exercise
        CHECK (exercise_id IS NOT NULL OR custom_exercise_name IS NOT NULL)
);

COMMENT ON TABLE public.workout_exercises IS 'セッション内の種目（種目IDまたはカスタム名を指定）';
COMMENT ON COLUMN public.workout_exercises.muscle_tag IS '対象部位タグ（chest, back, legs等）';
```

### 2.6 workout_sets（セット詳細）

```sql
CREATE TABLE public.workout_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workout_exercise_id UUID NOT NULL REFERENCES public.workout_exercises(id) ON DELETE CASCADE,
    set_index INTEGER NOT NULL CHECK (set_index >= 1),
    weight_kg NUMERIC(6,2) CHECK (weight_kg IS NULL OR weight_kg >= 0),
    reps INTEGER CHECK (reps IS NULL OR reps >= 0),
    rpe NUMERIC(3,1) CHECK (rpe IS NULL OR (rpe >= 1 AND rpe <= 10)),
    rest_sec INTEGER CHECK (rest_sec IS NULL OR rest_sec >= 0),
    tempo TEXT,
    is_warmup BOOLEAN NOT NULL DEFAULT FALSE,
    is_dropset BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT workout_sets_exercise_index_unique UNIQUE(workout_exercise_id, set_index)
);

COMMENT ON TABLE public.workout_sets IS '各種目のセット詳細';
COMMENT ON COLUMN public.workout_sets.rpe IS 'Rate of Perceived Exertion（主観的運動強度）1-10';
COMMENT ON COLUMN public.workout_sets.tempo IS 'テンポ表記（例: 3-1-2-0 = エキセントリック3秒-ボトム1秒-コンセントリック2秒-トップ0秒）';
```

### 2.7 meals（食事）

```sql
CREATE TABLE public.meals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    time TIME,
    meal_type TEXT NOT NULL
        CHECK (meal_type IN ('breakfast', 'lunch', 'dinner', 'snack', 'pre_workout', 'post_workout')),
    meal_index INTEGER NOT NULL DEFAULT 1 CHECK (meal_index >= 1 AND meal_index <= 10),
    note TEXT,
    photo_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.meals IS '食事記録';
COMMENT ON COLUMN public.meals.meal_type IS '食事タイプ: breakfast=朝食, lunch=昼食, dinner=夕食, snack=間食, pre_workout=トレ前, post_workout=トレ後';
COMMENT ON COLUMN public.meals.meal_index IS 'その日の何食目か（1〜meals_per_day）';
```

### 2.8 meal_items（食事の品目）

```sql
CREATE TABLE public.meal_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meal_id UUID NOT NULL REFERENCES public.meals(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    quantity NUMERIC(8,2) NOT NULL DEFAULT 1,
    unit TEXT NOT NULL DEFAULT 'serving',
    calories INTEGER CHECK (calories IS NULL OR calories >= 0),
    protein_g NUMERIC(6,2) CHECK (protein_g IS NULL OR protein_g >= 0),
    fat_g NUMERIC(6,2) CHECK (fat_g IS NULL OR fat_g >= 0),
    carbs_g NUMERIC(6,2) CHECK (carbs_g IS NULL OR carbs_g >= 0),
    fiber_g NUMERIC(6,2) CHECK (fiber_g IS NULL OR fiber_g >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.meal_items IS '食事の品目詳細';
COMMENT ON COLUMN public.meal_items.unit IS '単位: g, ml, serving, piece, cup, tbsp, tsp';
```

### 2.9 nutrition_daily（栄養の日次集計キャッシュ）

```sql
CREATE TABLE public.nutrition_daily (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    calories INTEGER NOT NULL DEFAULT 0,
    protein_g NUMERIC(7,2) NOT NULL DEFAULT 0,
    fat_g NUMERIC(7,2) NOT NULL DEFAULT 0,
    carbs_g NUMERIC(7,2) NOT NULL DEFAULT 0,
    fiber_g NUMERIC(6,2) NOT NULL DEFAULT 0,
    meals_logged INTEGER NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT nutrition_daily_user_date_unique UNIQUE(user_id, date)
);

COMMENT ON TABLE public.nutrition_daily IS '日次の栄養摂取集計（キャッシュテーブル）';
COMMENT ON COLUMN public.nutrition_daily.meals_logged IS 'その日に記録された食事数';
```

### 2.10 ai_sessions（AIセッション）

```sql
CREATE TABLE public.ai_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    intent TEXT NOT NULL,
    state_version TEXT NOT NULL DEFAULT 'v1',
    model TEXT NOT NULL DEFAULT 'gemini-1.5-flash',
    input_summary JSONB,
    safety_flags JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.ai_sessions IS 'AIコーチとの会話セッション';
COMMENT ON COLUMN public.ai_sessions.intent IS 'ユーザーの意図: ask, plan_today, menu_suggestion, diagnosis';
COMMENT ON COLUMN public.ai_sessions.input_summary IS '入力されたstate_jsonの要約';
COMMENT ON COLUMN public.ai_sessions.safety_flags IS '安全性フラグ: ["medical_advice", "extreme_diet"]';
```

### 2.11 ai_messages（AIメッセージ）

```sql
CREATE TABLE public.ai_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.ai_sessions(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.ai_messages IS 'セッション内のメッセージ履歴';
```

### 2.12 ai_recommendations（AIの推奨事項）

```sql
CREATE TABLE public.ai_recommendations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES public.ai_sessions(id) ON DELETE CASCADE,
    kind TEXT NOT NULL,
    payload JSONB NOT NULL,
    is_applied BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.ai_recommendations IS 'AIからの推奨事項（保存して資産化）';
COMMENT ON COLUMN public.ai_recommendations.kind IS '推奨タイプ: workout, nutrition, recovery, supplement';
COMMENT ON COLUMN public.ai_recommendations.payload IS '推奨内容のJSON: {"exercises": [...], "sets": 3, "reps": "8-12"}';
```

---

## 3. Indexes

```sql
-- body_metrics: ユーザー×日付での検索を高速化
CREATE INDEX idx_body_metrics_user_date
    ON public.body_metrics(user_id, date DESC);

-- workouts: ユーザー×日付での検索を高速化
CREATE INDEX idx_workouts_user_date
    ON public.workouts(user_id, date DESC);

-- workout_exercises: セッション内の種目検索
CREATE INDEX idx_workout_exercises_workout
    ON public.workout_exercises(workout_id);

-- workout_sets: 種目内のセット検索
CREATE INDEX idx_workout_sets_exercise_index
    ON public.workout_sets(workout_exercise_id, set_index);

-- meals: ユーザー×日付での検索を高速化
CREATE INDEX idx_meals_user_date
    ON public.meals(user_id, date DESC);

-- meal_items: 食事内の品目検索
CREATE INDEX idx_meal_items_meal
    ON public.meal_items(meal_id);

-- nutrition_daily: ユーザー×日付での検索を高速化
CREATE INDEX idx_nutrition_daily_user_date
    ON public.nutrition_daily(user_id, date DESC);

-- ai_sessions: ユーザーのセッション履歴を新しい順で取得
CREATE INDEX idx_ai_sessions_user_created
    ON public.ai_sessions(user_id, created_at DESC);

-- ai_messages: セッション内のメッセージ取得
CREATE INDEX idx_ai_messages_session
    ON public.ai_messages(session_id, created_at);

-- ai_recommendations: セッション内の推奨事項取得
CREATE INDEX idx_ai_recommendations_session
    ON public.ai_recommendations(session_id);

-- exercises: 種目検索用
CREATE INDEX idx_exercises_muscle
    ON public.exercises(primary_muscle);
```

---

## 4. Row Level Security (RLS)

```sql
-- RLSを有効化
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.body_metrics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_exercises ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.workout_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.meal_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nutrition_daily ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_recommendations ENABLE ROW LEVEL SECURITY;
```

### 4.1 user_profiles

```sql
CREATE POLICY "user_profiles_select_own" ON public.user_profiles
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "user_profiles_insert_own" ON public.user_profiles
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_profiles_update_own" ON public.user_profiles
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
```

### 4.2 body_metrics

```sql
CREATE POLICY "body_metrics_select_own" ON public.body_metrics
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "body_metrics_insert_own" ON public.body_metrics
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "body_metrics_update_own" ON public.body_metrics
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "body_metrics_delete_own" ON public.body_metrics
    FOR DELETE USING (auth.uid() = user_id);
```

### 4.3 exercises

```sql
-- システム種目は全員が参照可能
CREATE POLICY "exercises_select_system" ON public.exercises
    FOR SELECT USING (is_system = TRUE);

-- ユーザー定義の種目は本人のみ参照可能
CREATE POLICY "exercises_select_own" ON public.exercises
    FOR SELECT USING (created_by = auth.uid());

CREATE POLICY "exercises_insert_own" ON public.exercises
    FOR INSERT WITH CHECK (
        auth.uid() = created_by
        AND is_system = FALSE
    );

CREATE POLICY "exercises_update_own" ON public.exercises
    FOR UPDATE USING (
        auth.uid() = created_by
        AND is_system = FALSE
    )
    WITH CHECK (
        auth.uid() = created_by
        AND is_system = FALSE
    );

CREATE POLICY "exercises_delete_own" ON public.exercises
    FOR DELETE USING (
        auth.uid() = created_by
        AND is_system = FALSE
    );
```

### 4.4 workouts

```sql
CREATE POLICY "workouts_select_own" ON public.workouts
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "workouts_insert_own" ON public.workouts
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "workouts_update_own" ON public.workouts
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "workouts_delete_own" ON public.workouts
    FOR DELETE USING (auth.uid() = user_id);
```

### 4.5 workout_exercises（JOINによるRLS）

```sql
CREATE POLICY "workout_exercises_select_own" ON public.workout_exercises
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.workouts w
            WHERE w.id = workout_exercises.workout_id
            AND w.user_id = auth.uid()
        )
    );

CREATE POLICY "workout_exercises_insert_own" ON public.workout_exercises
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.workouts w
            WHERE w.id = workout_id
            AND w.user_id = auth.uid()
        )
    );

CREATE POLICY "workout_exercises_update_own" ON public.workout_exercises
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.workouts w
            WHERE w.id = workout_exercises.workout_id
            AND w.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.workouts w
            WHERE w.id = workout_id
            AND w.user_id = auth.uid()
        )
    );

CREATE POLICY "workout_exercises_delete_own" ON public.workout_exercises
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.workouts w
            WHERE w.id = workout_exercises.workout_id
            AND w.user_id = auth.uid()
        )
    );
```

### 4.6 workout_sets（JOINによるRLS）

```sql
CREATE POLICY "workout_sets_select_own" ON public.workout_sets
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.workout_exercises we
            JOIN public.workouts w ON w.id = we.workout_id
            WHERE we.id = workout_sets.workout_exercise_id
            AND w.user_id = auth.uid()
        )
    );

CREATE POLICY "workout_sets_insert_own" ON public.workout_sets
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.workout_exercises we
            JOIN public.workouts w ON w.id = we.workout_id
            WHERE we.id = workout_exercise_id
            AND w.user_id = auth.uid()
        )
    );

CREATE POLICY "workout_sets_update_own" ON public.workout_sets
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.workout_exercises we
            JOIN public.workouts w ON w.id = we.workout_id
            WHERE we.id = workout_sets.workout_exercise_id
            AND w.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.workout_exercises we
            JOIN public.workouts w ON w.id = we.workout_id
            WHERE we.id = workout_exercise_id
            AND w.user_id = auth.uid()
        )
    );

CREATE POLICY "workout_sets_delete_own" ON public.workout_sets
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.workout_exercises we
            JOIN public.workouts w ON w.id = we.workout_id
            WHERE we.id = workout_sets.workout_exercise_id
            AND w.user_id = auth.uid()
        )
    );
```

### 4.7 meals

```sql
CREATE POLICY "meals_select_own" ON public.meals
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "meals_insert_own" ON public.meals
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "meals_update_own" ON public.meals
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "meals_delete_own" ON public.meals
    FOR DELETE USING (auth.uid() = user_id);
```

### 4.8 meal_items（JOINによるRLS）

```sql
CREATE POLICY "meal_items_select_own" ON public.meal_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.meals m
            WHERE m.id = meal_items.meal_id
            AND m.user_id = auth.uid()
        )
    );

CREATE POLICY "meal_items_insert_own" ON public.meal_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.meals m
            WHERE m.id = meal_id
            AND m.user_id = auth.uid()
        )
    );

CREATE POLICY "meal_items_update_own" ON public.meal_items
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.meals m
            WHERE m.id = meal_items.meal_id
            AND m.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.meals m
            WHERE m.id = meal_id
            AND m.user_id = auth.uid()
        )
    );

CREATE POLICY "meal_items_delete_own" ON public.meal_items
    FOR DELETE USING (
        EXISTS (
            SELECT 1 FROM public.meals m
            WHERE m.id = meal_items.meal_id
            AND m.user_id = auth.uid()
        )
    );
```

### 4.9 nutrition_daily

```sql
CREATE POLICY "nutrition_daily_select_own" ON public.nutrition_daily
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "nutrition_daily_insert_own" ON public.nutrition_daily
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "nutrition_daily_update_own" ON public.nutrition_daily
    FOR UPDATE USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "nutrition_daily_delete_own" ON public.nutrition_daily
    FOR DELETE USING (auth.uid() = user_id);
```

### 4.10 ai_sessions

```sql
CREATE POLICY "ai_sessions_select_own" ON public.ai_sessions
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "ai_sessions_insert_own" ON public.ai_sessions
    FOR INSERT WITH CHECK (auth.uid() = user_id);
```

### 4.11 ai_messages（JOINによるRLS）

```sql
CREATE POLICY "ai_messages_select_own" ON public.ai_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.ai_sessions s
            WHERE s.id = ai_messages.session_id
            AND s.user_id = auth.uid()
        )
    );

CREATE POLICY "ai_messages_insert_own" ON public.ai_messages
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.ai_sessions s
            WHERE s.id = session_id
            AND s.user_id = auth.uid()
        )
    );
```

### 4.12 ai_recommendations（JOINによるRLS）

```sql
CREATE POLICY "ai_recommendations_select_own" ON public.ai_recommendations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.ai_sessions s
            WHERE s.id = ai_recommendations.session_id
            AND s.user_id = auth.uid()
        )
    );

CREATE POLICY "ai_recommendations_update_own" ON public.ai_recommendations
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.ai_sessions s
            WHERE s.id = ai_recommendations.session_id
            AND s.user_id = auth.uid()
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.ai_sessions s
            WHERE s.id = session_id
            AND s.user_id = auth.uid()
        )
    );
```

---

## 5. Triggers

### 5.1 updated_at自動更新

```sql
-- updated_at自動更新用関数
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- user_profiles
CREATE TRIGGER trg_user_profiles_updated_at
    BEFORE UPDATE ON public.user_profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- nutrition_daily
CREATE TRIGGER trg_nutrition_daily_updated_at
    BEFORE UPDATE ON public.nutrition_daily
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();
```

### 5.2 nutrition_daily自動集計

```sql
-- 食事品目追加/更新/削除時にnutrition_dailyを自動更新
CREATE OR REPLACE FUNCTION public.update_nutrition_daily()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_date DATE;
    v_meal_id UUID;
BEGIN
    -- 対象のmeal_idを取得
    IF TG_OP = 'DELETE' THEN
        v_meal_id := OLD.meal_id;
    ELSE
        v_meal_id := NEW.meal_id;
    END IF;

    -- meal_idから日付とuser_idを取得
    SELECT user_id, date INTO v_user_id, v_date
    FROM public.meals
    WHERE id = v_meal_id;

    -- mealsが見つからない場合は何もしない（CASCADE DELETEの場合など）
    IF v_user_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- nutrition_dailyを再集計（UPSERT）
    INSERT INTO public.nutrition_daily (user_id, date, calories, protein_g, fat_g, carbs_g, fiber_g, meals_logged, updated_at)
    SELECT
        m.user_id,
        m.date,
        COALESCE(SUM(mi.calories), 0)::INTEGER,
        COALESCE(SUM(mi.protein_g), 0),
        COALESCE(SUM(mi.fat_g), 0),
        COALESCE(SUM(mi.carbs_g), 0),
        COALESCE(SUM(mi.fiber_g), 0),
        COUNT(DISTINCT m.id)::INTEGER,
        NOW()
    FROM public.meals m
    LEFT JOIN public.meal_items mi ON mi.meal_id = m.id
    WHERE m.user_id = v_user_id AND m.date = v_date
    GROUP BY m.user_id, m.date
    ON CONFLICT (user_id, date)
    DO UPDATE SET
        calories = EXCLUDED.calories,
        protein_g = EXCLUDED.protein_g,
        fat_g = EXCLUDED.fat_g,
        carbs_g = EXCLUDED.carbs_g,
        fiber_g = EXCLUDED.fiber_g,
        meals_logged = EXCLUDED.meals_logged,
        updated_at = NOW();

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER trg_meal_items_update_nutrition
    AFTER INSERT OR UPDATE OR DELETE ON public.meal_items
    FOR EACH ROW
    EXECUTE FUNCTION public.update_nutrition_daily();
```

---

## 6. Functions (RPC)

### 6.1 新規ユーザー作成時のプロフィール自動作成

> **注意**: このトリガーは Supabase Dashboard の Authentication > Hooks で設定するか、
> SQL Editor で実行してください。auth.users への直接トリガーは権限が必要です。

```sql
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.user_profiles (user_id, display_name)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', 'User')
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Supabase Dashboard の SQL Editor で実行
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();
```

### 6.2 e1RM計算関数（Epley式）

```sql
CREATE OR REPLACE FUNCTION public.calculate_e1rm(
    p_weight_kg NUMERIC,
    p_reps INTEGER
)
RETURNS NUMERIC AS $$
BEGIN
    IF p_reps IS NULL OR p_reps <= 0 OR p_reps > 12 THEN
        RETURN p_weight_kg;
    END IF;
    RETURN ROUND(p_weight_kg * (1 + p_reps::NUMERIC / 30), 2);
END;
$$ LANGUAGE plpgsql IMMUTABLE;

COMMENT ON FUNCTION public.calculate_e1rm IS 'Epley式による推定1RM計算: e1rm = weight * (1 + reps/30)';
```

### 6.3 ワークアウト一括保存RPC

```sql
CREATE OR REPLACE FUNCTION public.save_workout(
    p_date DATE,
    p_start_time TIMESTAMPTZ DEFAULT NULL,
    p_end_time TIMESTAMPTZ DEFAULT NULL,
    p_perceived_fatigue INTEGER DEFAULT NULL,
    p_note TEXT DEFAULT NULL,
    p_exercises JSONB DEFAULT '[]'::jsonb
)
RETURNS UUID AS $$
DECLARE
    v_user_id UUID;
    v_workout_id UUID;
    v_exercise JSONB;
    v_workout_exercise_id UUID;
    v_set JSONB;
    v_set_index INTEGER;
    v_exercise_order INTEGER := 0;
BEGIN
    -- 認証チェック
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- workoutを作成
    INSERT INTO public.workouts (user_id, date, start_time, end_time, perceived_fatigue, note)
    VALUES (v_user_id, p_date, p_start_time, p_end_time, p_perceived_fatigue, p_note)
    RETURNING id INTO v_workout_id;

    -- 各exerciseを処理
    FOR v_exercise IN SELECT * FROM jsonb_array_elements(p_exercises)
    LOOP
        v_exercise_order := v_exercise_order + 1;

        INSERT INTO public.workout_exercises (
            workout_id,
            exercise_id,
            custom_exercise_name,
            muscle_tag,
            exercise_order
        )
        VALUES (
            v_workout_id,
            (v_exercise->>'exercise_id')::UUID,
            v_exercise->>'custom_name',
            COALESCE(v_exercise->>'muscle_tag', 'other'),
            v_exercise_order
        )
        RETURNING id INTO v_workout_exercise_id;

        -- 各setを処理
        v_set_index := 0;
        FOR v_set IN SELECT * FROM jsonb_array_elements(COALESCE(v_exercise->'sets', '[]'::jsonb))
        LOOP
            v_set_index := v_set_index + 1;
            INSERT INTO public.workout_sets (
                workout_exercise_id,
                set_index,
                weight_kg,
                reps,
                rpe,
                rest_sec,
                is_warmup,
                is_dropset
            )
            VALUES (
                v_workout_exercise_id,
                v_set_index,
                (v_set->>'weight_kg')::NUMERIC,
                (v_set->>'reps')::INTEGER,
                (v_set->>'rpe')::NUMERIC,
                (v_set->>'rest_sec')::INTEGER,
                COALESCE((v_set->>'is_warmup')::BOOLEAN, FALSE),
                COALESCE((v_set->>'is_dropset')::BOOLEAN, FALSE)
            );
        END LOOP;
    END LOOP;

    RETURN v_workout_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION public.save_workout IS 'ワークアウト（種目・セット含む）を一括保存';
```

### 6.4 ダッシュボード用日次データ取得

```sql
CREATE OR REPLACE FUNCTION public.get_dashboard_today(p_date DATE DEFAULT CURRENT_DATE)
RETURNS JSONB AS $$
DECLARE
    v_user_id UUID;
    v_result JSONB;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT jsonb_build_object(
        'date', p_date,
        'body_metrics', (
            SELECT jsonb_build_object(
                'weight_kg', weight_kg,
                'bodyfat_pct', bodyfat_pct,
                'sleep_hours', sleep_hours,
                'steps', steps
            )
            FROM public.body_metrics
            WHERE user_id = v_user_id AND date = p_date
        ),
        'nutrition', (
            SELECT jsonb_build_object(
                'calories', calories,
                'protein_g', protein_g,
                'fat_g', fat_g,
                'carbs_g', carbs_g,
                'meals_logged', meals_logged
            )
            FROM public.nutrition_daily
            WHERE user_id = v_user_id AND date = p_date
        ),
        'workout_count', (
            SELECT COUNT(*)
            FROM public.workouts
            WHERE user_id = v_user_id AND date = p_date
        )
    ) INTO v_result;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 7. Seed Data（初期データ）

### 7.1 システム種目マスタ

```sql
INSERT INTO public.exercises (name, name_en, primary_muscle, secondary_muscles, equipment, is_system) VALUES
-- ============================================
-- 胸 (chest) - 20種目
-- ============================================
('ベンチプレス', 'Bench Press', 'chest', ARRAY['triceps', 'shoulder'], 'barbell', TRUE),
('ダンベルプレス', 'Dumbbell Press', 'chest', ARRAY['triceps', 'shoulder'], 'dumbbell', TRUE),
('インクラインベンチプレス', 'Incline Bench Press', 'chest', ARRAY['triceps', 'shoulder'], 'barbell', TRUE),
('インクラインダンベルプレス', 'Incline Dumbbell Press', 'chest', ARRAY['triceps', 'shoulder'], 'dumbbell', TRUE),
('デクラインベンチプレス', 'Decline Bench Press', 'chest', ARRAY['triceps'], 'barbell', TRUE),
('デクラインダンベルプレス', 'Decline Dumbbell Press', 'chest', ARRAY['triceps'], 'dumbbell', TRUE),
('ダンベルフライ', 'Dumbbell Fly', 'chest', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('インクラインダンベルフライ', 'Incline Dumbbell Fly', 'chest', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ケーブルクロスオーバー', 'Cable Crossover', 'chest', ARRAY[]::TEXT[], 'cable', TRUE),
('ロープレスケーブルフライ', 'Low Cable Fly', 'chest', ARRAY[]::TEXT[], 'cable', TRUE),
('ハイケーブルフライ', 'High Cable Fly', 'chest', ARRAY[]::TEXT[], 'cable', TRUE),
('チェストプレス', 'Chest Press Machine', 'chest', ARRAY['triceps'], 'machine', TRUE),
('ペックデック', 'Pec Deck', 'chest', ARRAY[]::TEXT[], 'machine', TRUE),
('スミスマシンベンチプレス', 'Smith Machine Bench Press', 'chest', ARRAY['triceps', 'shoulder'], 'machine', TRUE),
('腕立て伏せ', 'Push Up', 'chest', ARRAY['triceps', 'shoulder'], 'bodyweight', TRUE),
('ワイドプッシュアップ', 'Wide Push Up', 'chest', ARRAY['triceps'], 'bodyweight', TRUE),
('ディップス', 'Dips', 'chest', ARRAY['triceps'], 'bodyweight', TRUE),
('ダンベルプルオーバー', 'Dumbbell Pullover', 'chest', ARRAY['back'], 'dumbbell', TRUE),
('フロアプレス', 'Floor Press', 'chest', ARRAY['triceps'], 'barbell', TRUE),
('スヴェンドプレス', 'Svend Press', 'chest', ARRAY[]::TEXT[], 'dumbbell', TRUE),

-- ============================================
-- 背中 (back) - 22種目
-- ============================================
('デッドリフト', 'Deadlift', 'back', ARRAY['hamstrings', 'glutes'], 'barbell', TRUE),
('ラットプルダウン', 'Lat Pulldown', 'back', ARRAY['biceps'], 'cable', TRUE),
('ワイドグリップラットプルダウン', 'Wide Grip Lat Pulldown', 'back', ARRAY['biceps'], 'cable', TRUE),
('クローズグリップラットプルダウン', 'Close Grip Lat Pulldown', 'back', ARRAY['biceps'], 'cable', TRUE),
('ビハインドネックラットプルダウン', 'Behind Neck Lat Pulldown', 'back', ARRAY['biceps'], 'cable', TRUE),
('チンニング', 'Chin Up', 'back', ARRAY['biceps'], 'bodyweight', TRUE),
('懸垂', 'Pull Up', 'back', ARRAY['biceps'], 'bodyweight', TRUE),
('ワイドグリップ懸垂', 'Wide Grip Pull Up', 'back', ARRAY['biceps'], 'bodyweight', TRUE),
('ベントオーバーロウ', 'Bent Over Row', 'back', ARRAY['biceps'], 'barbell', TRUE),
('ダンベルロウ', 'Dumbbell Row', 'back', ARRAY['biceps'], 'dumbbell', TRUE),
('ワンアームダンベルロウ', 'One Arm Dumbbell Row', 'back', ARRAY['biceps'], 'dumbbell', TRUE),
('シーテッドロウ', 'Seated Row', 'back', ARRAY['biceps'], 'cable', TRUE),
('ケーブルロウ', 'Cable Row', 'back', ARRAY['biceps'], 'cable', TRUE),
('Tバーロウ', 'T-Bar Row', 'back', ARRAY['biceps'], 'barbell', TRUE),
('ペンドレイロウ', 'Pendlay Row', 'back', ARRAY['biceps'], 'barbell', TRUE),
('マシンロウ', 'Machine Row', 'back', ARRAY['biceps'], 'machine', TRUE),
('ストレートアームプルダウン', 'Straight Arm Pulldown', 'back', ARRAY[]::TEXT[], 'cable', TRUE),
('シールロウ', 'Seal Row', 'back', ARRAY['biceps'], 'barbell', TRUE),
('インバーテッドロウ', 'Inverted Row', 'back', ARRAY['biceps'], 'bodyweight', TRUE),
('ケーブルプルオーバー', 'Cable Pullover', 'back', ARRAY['chest'], 'cable', TRUE),
('シュラッグ', 'Shrug', 'back', ARRAY[]::TEXT[], 'barbell', TRUE),
('ダンベルシュラッグ', 'Dumbbell Shrug', 'back', ARRAY[]::TEXT[], 'dumbbell', TRUE),

-- ============================================
-- 肩 (shoulder) - 18種目
-- ============================================
('オーバーヘッドプレス', 'Overhead Press', 'shoulder', ARRAY['triceps'], 'barbell', TRUE),
('ダンベルショルダープレス', 'Dumbbell Shoulder Press', 'shoulder', ARRAY['triceps'], 'dumbbell', TRUE),
('アーノルドプレス', 'Arnold Press', 'shoulder', ARRAY['triceps'], 'dumbbell', TRUE),
('シーテッドショルダープレス', 'Seated Shoulder Press', 'shoulder', ARRAY['triceps'], 'barbell', TRUE),
('マシンショルダープレス', 'Machine Shoulder Press', 'shoulder', ARRAY['triceps'], 'machine', TRUE),
('スミスマシンショルダープレス', 'Smith Machine Shoulder Press', 'shoulder', ARRAY['triceps'], 'machine', TRUE),
('プッシュプレス', 'Push Press', 'shoulder', ARRAY['triceps', 'quadriceps'], 'barbell', TRUE),
('サイドレイズ', 'Lateral Raise', 'shoulder', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ケーブルサイドレイズ', 'Cable Lateral Raise', 'shoulder', ARRAY[]::TEXT[], 'cable', TRUE),
('マシンサイドレイズ', 'Machine Lateral Raise', 'shoulder', ARRAY[]::TEXT[], 'machine', TRUE),
('フロントレイズ', 'Front Raise', 'shoulder', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ケーブルフロントレイズ', 'Cable Front Raise', 'shoulder', ARRAY[]::TEXT[], 'cable', TRUE),
('プレートフロントレイズ', 'Plate Front Raise', 'shoulder', ARRAY[]::TEXT[], 'barbell', TRUE),
('リアデルトフライ', 'Rear Delt Fly', 'shoulder', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('リアデルトマシン', 'Rear Delt Machine', 'shoulder', ARRAY[]::TEXT[], 'machine', TRUE),
('フェイスプル', 'Face Pull', 'shoulder', ARRAY[]::TEXT[], 'cable', TRUE),
('アップライトロウ', 'Upright Row', 'shoulder', ARRAY['biceps'], 'barbell', TRUE),
('ケーブルアップライトロウ', 'Cable Upright Row', 'shoulder', ARRAY['biceps'], 'cable', TRUE),

-- ============================================
-- 上腕二頭筋 (biceps) - 15種目
-- ============================================
('バーベルカール', 'Barbell Curl', 'biceps', ARRAY[]::TEXT[], 'barbell', TRUE),
('EZバーカール', 'EZ Bar Curl', 'biceps', ARRAY[]::TEXT[], 'barbell', TRUE),
('ダンベルカール', 'Dumbbell Curl', 'biceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('オルタネイトダンベルカール', 'Alternate Dumbbell Curl', 'biceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ハンマーカール', 'Hammer Curl', 'biceps', ARRAY['forearm'], 'dumbbell', TRUE),
('プリーチャーカール', 'Preacher Curl', 'biceps', ARRAY[]::TEXT[], 'barbell', TRUE),
('ダンベルプリーチャーカール', 'Dumbbell Preacher Curl', 'biceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('インクラインカール', 'Incline Curl', 'biceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('コンセントレーションカール', 'Concentration Curl', 'biceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ケーブルカール', 'Cable Curl', 'biceps', ARRAY[]::TEXT[], 'cable', TRUE),
('ハイケーブルカール', 'High Cable Curl', 'biceps', ARRAY[]::TEXT[], 'cable', TRUE),
('マシンカール', 'Machine Curl', 'biceps', ARRAY[]::TEXT[], 'machine', TRUE),
('スパイダーカール', 'Spider Curl', 'biceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ドラッグカール', 'Drag Curl', 'biceps', ARRAY[]::TEXT[], 'barbell', TRUE),
('21カール', '21s Curl', 'biceps', ARRAY[]::TEXT[], 'barbell', TRUE),

-- ============================================
-- 上腕三頭筋 (triceps) - 15種目
-- ============================================
('トライセプスプッシュダウン', 'Triceps Pushdown', 'triceps', ARRAY[]::TEXT[], 'cable', TRUE),
('ロープトライセプスプッシュダウン', 'Rope Triceps Pushdown', 'triceps', ARRAY[]::TEXT[], 'cable', TRUE),
('Vバートライセプスプッシュダウン', 'V-Bar Triceps Pushdown', 'triceps', ARRAY[]::TEXT[], 'cable', TRUE),
('スカルクラッシャー', 'Skull Crusher', 'triceps', ARRAY[]::TEXT[], 'barbell', TRUE),
('ダンベルスカルクラッシャー', 'Dumbbell Skull Crusher', 'triceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('オーバーヘッドエクステンション', 'Overhead Extension', 'triceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ケーブルオーバーヘッドエクステンション', 'Cable Overhead Extension', 'triceps', ARRAY[]::TEXT[], 'cable', TRUE),
('キックバック', 'Kickback', 'triceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ケーブルキックバック', 'Cable Kickback', 'triceps', ARRAY[]::TEXT[], 'cable', TRUE),
('クローズグリップベンチプレス', 'Close Grip Bench Press', 'triceps', ARRAY['chest'], 'barbell', TRUE),
('ダイヤモンドプッシュアップ', 'Diamond Push Up', 'triceps', ARRAY['chest'], 'bodyweight', TRUE),
('トライセプスディップス', 'Triceps Dips', 'triceps', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('ベンチディップス', 'Bench Dips', 'triceps', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('JMプレス', 'JM Press', 'triceps', ARRAY['chest'], 'barbell', TRUE),
('トライセプスマシン', 'Triceps Machine', 'triceps', ARRAY[]::TEXT[], 'machine', TRUE),

-- ============================================
-- 前腕 (forearm) - 8種目
-- ============================================
('リストカール', 'Wrist Curl', 'forearm', ARRAY[]::TEXT[], 'barbell', TRUE),
('ダンベルリストカール', 'Dumbbell Wrist Curl', 'forearm', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('リバースリストカール', 'Reverse Wrist Curl', 'forearm', ARRAY[]::TEXT[], 'barbell', TRUE),
('リバースカール', 'Reverse Curl', 'forearm', ARRAY['biceps'], 'barbell', TRUE),
('ダンベルリバースカール', 'Dumbbell Reverse Curl', 'forearm', ARRAY['biceps'], 'dumbbell', TRUE),
('ファーマーズウォーク', 'Farmers Walk', 'forearm', ARRAY['back'], 'dumbbell', TRUE),
('プレートピンチ', 'Plate Pinch', 'forearm', ARRAY[]::TEXT[], 'barbell', TRUE),
('グリッパー', 'Hand Gripper', 'forearm', ARRAY[]::TEXT[], 'bodyweight', TRUE),

-- ============================================
-- 脚・大腿四頭筋 (quadriceps) - 15種目
-- ============================================
('スクワット', 'Squat', 'quadriceps', ARRAY['glutes', 'hamstrings'], 'barbell', TRUE),
('フロントスクワット', 'Front Squat', 'quadriceps', ARRAY['glutes'], 'barbell', TRUE),
('ハイバースクワット', 'High Bar Squat', 'quadriceps', ARRAY['glutes', 'hamstrings'], 'barbell', TRUE),
('ローバースクワット', 'Low Bar Squat', 'quadriceps', ARRAY['glutes', 'hamstrings'], 'barbell', TRUE),
('レッグプレス', 'Leg Press', 'quadriceps', ARRAY['glutes'], 'machine', TRUE),
('ナローレッグプレス', 'Narrow Leg Press', 'quadriceps', ARRAY[]::TEXT[], 'machine', TRUE),
('レッグエクステンション', 'Leg Extension', 'quadriceps', ARRAY[]::TEXT[], 'machine', TRUE),
('ブルガリアンスクワット', 'Bulgarian Split Squat', 'quadriceps', ARRAY['glutes'], 'dumbbell', TRUE),
('ハックスクワット', 'Hack Squat', 'quadriceps', ARRAY['glutes'], 'machine', TRUE),
('ゴブレットスクワット', 'Goblet Squat', 'quadriceps', ARRAY['glutes'], 'dumbbell', TRUE),
('ランジ', 'Lunge', 'quadriceps', ARRAY['glutes'], 'bodyweight', TRUE),
('ウォーキングランジ', 'Walking Lunge', 'quadriceps', ARRAY['glutes'], 'dumbbell', TRUE),
('リバースランジ', 'Reverse Lunge', 'quadriceps', ARRAY['glutes'], 'dumbbell', TRUE),
('シシースクワット', 'Sissy Squat', 'quadriceps', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('ステップアップ', 'Step Up', 'quadriceps', ARRAY['glutes'], 'dumbbell', TRUE),

-- ============================================
-- 脚・ハムストリングス (hamstrings) - 10種目
-- ============================================
('レッグカール', 'Leg Curl', 'hamstrings', ARRAY[]::TEXT[], 'machine', TRUE),
('シーテッドレッグカール', 'Seated Leg Curl', 'hamstrings', ARRAY[]::TEXT[], 'machine', TRUE),
('ライイングレッグカール', 'Lying Leg Curl', 'hamstrings', ARRAY[]::TEXT[], 'machine', TRUE),
('ルーマニアンデッドリフト', 'Romanian Deadlift', 'hamstrings', ARRAY['glutes'], 'barbell', TRUE),
('ダンベルルーマニアンデッドリフト', 'Dumbbell Romanian Deadlift', 'hamstrings', ARRAY['glutes'], 'dumbbell', TRUE),
('スティッフレッグデッドリフト', 'Stiff Leg Deadlift', 'hamstrings', ARRAY['glutes'], 'barbell', TRUE),
('グッドモーニング', 'Good Morning', 'hamstrings', ARRAY['back'], 'barbell', TRUE),
('ノルディックハムカール', 'Nordic Ham Curl', 'hamstrings', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('グルートハムレイズ', 'Glute Ham Raise', 'hamstrings', ARRAY['glutes'], 'bodyweight', TRUE),
('ケーブルプルスルー', 'Cable Pull Through', 'hamstrings', ARRAY['glutes'], 'cable', TRUE),

-- ============================================
-- 臀部 (glutes) - 12種目
-- ============================================
('ヒップスラスト', 'Hip Thrust', 'glutes', ARRAY['hamstrings'], 'barbell', TRUE),
('ダンベルヒップスラスト', 'Dumbbell Hip Thrust', 'glutes', ARRAY['hamstrings'], 'dumbbell', TRUE),
('シングルレッグヒップスラスト', 'Single Leg Hip Thrust', 'glutes', ARRAY['hamstrings'], 'bodyweight', TRUE),
('グルートブリッジ', 'Glute Bridge', 'glutes', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('シングルレッググルートブリッジ', 'Single Leg Glute Bridge', 'glutes', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('ケーブルヒップアブダクション', 'Cable Hip Abduction', 'glutes', ARRAY[]::TEXT[], 'cable', TRUE),
('マシンヒップアブダクション', 'Machine Hip Abduction', 'glutes', ARRAY[]::TEXT[], 'machine', TRUE),
('マシンヒップアダクション', 'Machine Hip Adduction', 'glutes', ARRAY[]::TEXT[], 'machine', TRUE),
('ドンキーキック', 'Donkey Kick', 'glutes', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('ファイヤーハイドラント', 'Fire Hydrant', 'glutes', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('クラムシェル', 'Clamshell', 'glutes', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('スモウデッドリフト', 'Sumo Deadlift', 'glutes', ARRAY['hamstrings', 'quadriceps'], 'barbell', TRUE),

-- ============================================
-- ふくらはぎ (calves) - 8種目
-- ============================================
('スタンディングカーフレイズ', 'Standing Calf Raise', 'calves', ARRAY[]::TEXT[], 'machine', TRUE),
('シーテッドカーフレイズ', 'Seated Calf Raise', 'calves', ARRAY[]::TEXT[], 'machine', TRUE),
('レッグプレスカーフレイズ', 'Leg Press Calf Raise', 'calves', ARRAY[]::TEXT[], 'machine', TRUE),
('ドンキーカーフレイズ', 'Donkey Calf Raise', 'calves', ARRAY[]::TEXT[], 'machine', TRUE),
('スミスマシンカーフレイズ', 'Smith Machine Calf Raise', 'calves', ARRAY[]::TEXT[], 'machine', TRUE),
('ダンベルカーフレイズ', 'Dumbbell Calf Raise', 'calves', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('シングルレッグカーフレイズ', 'Single Leg Calf Raise', 'calves', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('バーベルカーフレイズ', 'Barbell Calf Raise', 'calves', ARRAY[]::TEXT[], 'barbell', TRUE),

-- ============================================
-- 腹筋・コア (abs) - 20種目
-- ============================================
('クランチ', 'Crunch', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('シットアップ', 'Sit Up', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('リバースクランチ', 'Reverse Crunch', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('バイシクルクランチ', 'Bicycle Crunch', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('レッグレイズ', 'Leg Raise', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('ハンギングレッグレイズ', 'Hanging Leg Raise', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('ハンギングニーレイズ', 'Hanging Knee Raise', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('キャプテンズチェアレッグレイズ', 'Captains Chair Leg Raise', 'abs', ARRAY[]::TEXT[], 'machine', TRUE),
('プランク', 'Plank', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('サイドプランク', 'Side Plank', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('デッドバグ', 'Dead Bug', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('マウンテンクライマー', 'Mountain Climber', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('アブローラー', 'Ab Roller', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('ケーブルクランチ', 'Cable Crunch', 'abs', ARRAY[]::TEXT[], 'cable', TRUE),
('ウッドチョップ', 'Wood Chop', 'abs', ARRAY[]::TEXT[], 'cable', TRUE),
('ロシアンツイスト', 'Russian Twist', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('Vアップ', 'V Up', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('トーズトゥバー', 'Toes to Bar', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('アブマシン', 'Ab Machine', 'abs', ARRAY[]::TEXT[], 'machine', TRUE),
('パロフプレス', 'Pallof Press', 'abs', ARRAY[]::TEXT[], 'cable', TRUE);
```

---

## 8. ER図（テーブル関係）

```
auth.users
    │
    ├──< user_profiles (1:1)
    │
    ├──< body_metrics (1:N)
    │
    ├──< workouts (1:N)
    │       │
    │       └──< workout_exercises (1:N)
    │               │
    │               ├──> exercises (N:1, optional)
    │               │
    │               └──< workout_sets (1:N)
    │
    ├──< meals (1:N)
    │       │
    │       └──< meal_items (1:N)
    │
    ├──< nutrition_daily (1:N, cache)
    │
    └──< ai_sessions (1:N)
            │
            ├──< ai_messages (1:N)
            │
            └──< ai_recommendations (1:N)
```

---

## 9. テーブル一覧サマリ

| テーブル名 | 説明 | user_id | RLS |
|-----------|------|---------|-----|
| user_profiles | ユーザープロフィール | PK | auth.uid() = user_id |
| body_metrics | 体重・体脂肪等 | FK | auth.uid() = user_id |
| exercises | 種目マスタ | - | is_system OR created_by = auth.uid() |
| workouts | トレーニングセッション | FK | auth.uid() = user_id |
| workout_exercises | セッション内種目 | - | JOIN workouts |
| workout_sets | セット詳細 | - | JOIN workout_exercises → workouts |
| meals | 食事 | FK | auth.uid() = user_id |
| meal_items | 食事品目 | - | JOIN meals |
| nutrition_daily | 栄養日次集計 | FK | auth.uid() = user_id |
| ai_sessions | AIセッション | FK | auth.uid() = user_id |
| ai_messages | AIメッセージ | - | JOIN ai_sessions |
| ai_recommendations | AI推奨事項 | - | JOIN ai_sessions |

---

## 10. Migration実行順序

Supabase SQL Editor で以下の順番で実行してください：

1. **Extensions** (セクション1)
2. **Tables** (セクション2) - 依存関係順に実行
3. **Indexes** (セクション3)
4. **RLS Enable + Policies** (セクション4)
5. **Triggers** (セクション5)
6. **Functions** (セクション6)
7. **Seed Data** (セクション7)

---

## 11. 修正履歴

- `uuid_generate_v4()` → `gen_random_uuid()` (Supabase推奨)
- 配列リテラル `'{}'` → `ARRAY[]::TEXT[]` (明示的な型)
- CHECK制約に NULL 許容を明記
- exercises の UNIQUE 制約を部分インデックスに変更（NULL問題対応）
- RLS ポリシーに WITH CHECK 追加（INSERT/UPDATE）
- nutrition_daily トリガーの NULL チェック追加
- save_workout RPC に認証チェック追加
- 全テーブルに `public.` スキーマを明記
