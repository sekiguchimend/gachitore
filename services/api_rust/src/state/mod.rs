use chrono::{Duration, NaiveDate};
use serde::{Deserialize, Serialize};

use crate::error::AppResult;
use crate::infrastructure::supabase::{
    BodyMetrics, NutritionDaily, SupabaseClient, UserProfile, Workout, WorkoutExercise, WorkoutSet,
};

/// User state for AI context (version 1)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserState {
    pub version: String,
    pub profile: ProfileState,
    pub today: TodayState,
    pub last_14d: Last14dState,
    pub nutrition_7d_avg: NutritionAvgState,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProfileState {
    pub goal: String,
    pub training_level: String,
    pub height_cm: Option<i32>,
    pub sex: Option<String>,
    pub environment: serde_json::Value,
    pub constraints: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TodayState {
    pub date: NaiveDate,
    pub weight_kg: Option<f64>,
    pub bodyfat_pct: Option<f64>,
    pub sleep_hours: Option<f64>,
    pub steps: Option<i32>,
    pub calories: Option<i32>,
    pub protein_g: Option<f64>,
    pub meals_logged: Option<i32>,
    pub workout_count: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Last14dState {
    pub workout_count: i32,
    pub workout_days: Vec<NaiveDate>,
    pub muscle_groups_trained: Vec<String>,
    pub top_exercises: Vec<ExerciseSummary>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExerciseSummary {
    pub name: String,
    pub muscle_tag: String,
    pub e1rm: Option<f64>,
    pub last_weight_kg: Option<f64>,
    pub last_reps: Option<i32>,
    pub trend: String, // "up", "down", "stable"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NutritionAvgState {
    pub avg_calories: Option<f64>,
    pub avg_protein_g: Option<f64>,
    pub avg_fat_g: Option<f64>,
    pub avg_carbs_g: Option<f64>,
    pub days_logged: i32,
}

/// State generator using Supabase REST API
pub struct StateGenerator<'a> {
    supabase: &'a SupabaseClient,
    access_token: &'a str,
}

impl<'a> StateGenerator<'a> {
    pub fn new(supabase: &'a SupabaseClient, access_token: &'a str) -> Self {
        Self {
            supabase,
            access_token,
        }
    }

    /// Generate complete user state for AI context
    pub async fn generate(&self, user_id: &str, target_date: NaiveDate) -> AppResult<UserState> {
        let profile = self.generate_profile(user_id).await?;
        let today = self.generate_today(user_id, target_date).await?;
        let last_14d = self.generate_last_14d(user_id, target_date).await?;
        let nutrition_7d_avg = self.generate_nutrition_avg(user_id, target_date).await?;

        Ok(UserState {
            version: "v1".to_string(),
            profile,
            today,
            last_14d,
            nutrition_7d_avg,
        })
    }

    async fn generate_profile(&self, user_id: &str) -> AppResult<ProfileState> {
        let query = format!("user_id=eq.{}&select=*", user_id);
        let profiles: Vec<UserProfile> = self
            .supabase
            .select("user_profiles", &query, self.access_token)
            .await?;

        match profiles.into_iter().next() {
            Some(p) => Ok(ProfileState {
                goal: p.goal,
                training_level: p.training_level,
                height_cm: p.height_cm,
                sex: p.sex,
                environment: p.environment.unwrap_or(serde_json::json!({})),
                constraints: p.constraints.unwrap_or(serde_json::json!([])),
            }),
            None => Ok(ProfileState {
                goal: "health".to_string(),
                training_level: "beginner".to_string(),
                height_cm: None,
                sex: None,
                environment: serde_json::json!({}),
                constraints: serde_json::json!([]),
            }),
        }
    }

    async fn generate_today(&self, user_id: &str, date: NaiveDate) -> AppResult<TodayState> {
        let date_str = date.format("%Y-%m-%d").to_string();

        // Get body metrics
        let metrics_query = format!("user_id=eq.{}&date=eq.{}&select=*", user_id, date_str);
        let metrics: Vec<BodyMetrics> = self
            .supabase
            .select("body_metrics", &metrics_query, self.access_token)
            .await?;
        let metrics = metrics.into_iter().next();

        // Get nutrition
        let nutrition_query = format!("user_id=eq.{}&date=eq.{}&select=*", user_id, date_str);
        let nutrition: Vec<NutritionDaily> = self
            .supabase
            .select("nutrition_daily", &nutrition_query, self.access_token)
            .await?;
        let nutrition = nutrition.into_iter().next();

        // Get workouts
        let workouts_query = format!("user_id=eq.{}&date=eq.{}&select=*", user_id, date_str);
        let workouts: Vec<Workout> = self
            .supabase
            .select("workouts", &workouts_query, self.access_token)
            .await?;

        Ok(TodayState {
            date,
            weight_kg: metrics.as_ref().and_then(|m| m.weight_kg),
            bodyfat_pct: metrics.as_ref().and_then(|m| m.bodyfat_pct),
            sleep_hours: metrics.as_ref().and_then(|m| m.sleep_hours),
            steps: metrics.as_ref().and_then(|m| m.steps),
            calories: nutrition.as_ref().map(|n| n.calories),
            protein_g: nutrition.as_ref().map(|n| n.protein_g),
            meals_logged: nutrition.as_ref().map(|n| n.meals_logged),
            workout_count: workouts.len() as i32,
        })
    }

    async fn generate_last_14d(&self, user_id: &str, end_date: NaiveDate) -> AppResult<Last14dState> {
        let start_date = end_date - Duration::days(14);
        let start_str = start_date.format("%Y-%m-%d").to_string();
        let end_str = end_date.format("%Y-%m-%d").to_string();

        // Get workouts in range
        let workouts_query = format!(
            "user_id=eq.{}&date=gte.{}&date=lte.{}&select=*&order=date.desc",
            user_id, start_str, end_str
        );
        let workouts: Vec<Workout> = self
            .supabase
            .select("workouts", &workouts_query, self.access_token)
            .await?;

        let workout_days: Vec<NaiveDate> = workouts
            .iter()
            .filter_map(|w| NaiveDate::parse_from_str(&w.date, "%Y-%m-%d").ok())
            .collect();

        let mut muscle_groups: std::collections::HashSet<String> = std::collections::HashSet::new();
        let mut exercise_data: std::collections::HashMap<String, Vec<(f64, i32, String)>> =
            std::collections::HashMap::new();

        // Get exercises for each workout
        for workout in &workouts {
            let exercises_query = format!(
                "workout_id=eq.{}&select=*&order=exercise_order",
                workout.id
            );
            let exercises: Vec<WorkoutExercise> = self
                .supabase
                .select("workout_exercises", &exercises_query, self.access_token)
                .await?;

            for exercise in &exercises {
                muscle_groups.insert(exercise.muscle_tag.clone());

                let name = exercise
                    .custom_exercise_name
                    .clone()
                    .unwrap_or_else(|| {
                        format!(
                            "exercise_{}",
                            exercise.exercise_id.as_deref().unwrap_or("unknown")
                        )
                    });

                // Get sets for this exercise
                let sets_query = format!(
                    "workout_exercise_id=eq.{}&select=*&order=set_index",
                    exercise.id
                );
                let sets: Vec<WorkoutSet> = self
                    .supabase
                    .select("workout_sets", &sets_query, self.access_token)
                    .await?;

                for set in &sets {
                    if !set.is_warmup {
                        if let (Some(weight), Some(reps)) = (set.weight_kg, set.reps) {
                            exercise_data
                                .entry(name.clone())
                                .or_default()
                                .push((weight, reps, exercise.muscle_tag.clone()));
                        }
                    }
                }
            }
        }

        // Calculate top exercises with e1RM
        let mut top_exercises: Vec<ExerciseSummary> = exercise_data
            .into_iter()
            .filter_map(|(name, sets)| {
                if sets.is_empty() {
                    return None;
                }

                let last = sets.last()?;
                let first = sets.first()?;

                let e1rm = calculate_e1rm(last.0, last.1);
                let first_e1rm = calculate_e1rm(first.0, first.1);

                let trend = if e1rm > first_e1rm * 1.02 {
                    "up"
                } else if e1rm < first_e1rm * 0.98 {
                    "down"
                } else {
                    "stable"
                };

                Some(ExerciseSummary {
                    name,
                    muscle_tag: last.2.clone(),
                    e1rm: Some(e1rm),
                    last_weight_kg: Some(last.0),
                    last_reps: Some(last.1),
                    trend: trend.to_string(),
                })
            })
            .collect();

        // Sort by e1RM descending and take top 10
        top_exercises.sort_by(|a, b| {
            b.e1rm
                .unwrap_or(0.0)
                .partial_cmp(&a.e1rm.unwrap_or(0.0))
                .unwrap()
        });
        top_exercises.truncate(10);

        Ok(Last14dState {
            workout_count: workouts.len() as i32,
            workout_days,
            muscle_groups_trained: muscle_groups.into_iter().collect(),
            top_exercises,
        })
    }

    async fn generate_nutrition_avg(
        &self,
        user_id: &str,
        end_date: NaiveDate,
    ) -> AppResult<NutritionAvgState> {
        let start_date = end_date - Duration::days(7);
        let start_str = start_date.format("%Y-%m-%d").to_string();
        let end_str = end_date.format("%Y-%m-%d").to_string();

        let query = format!(
            "user_id=eq.{}&date=gte.{}&date=lte.{}&select=*&order=date.desc",
            user_id, start_str, end_str
        );
        let nutrition: Vec<NutritionDaily> = self
            .supabase
            .select("nutrition_daily", &query, self.access_token)
            .await?;

        if nutrition.is_empty() {
            return Ok(NutritionAvgState {
                avg_calories: None,
                avg_protein_g: None,
                avg_fat_g: None,
                avg_carbs_g: None,
                days_logged: 0,
            });
        }

        let count = nutrition.len() as f64;
        let total_calories: f64 = nutrition.iter().map(|n| n.calories as f64).sum();
        let total_protein: f64 = nutrition.iter().map(|n| n.protein_g).sum();
        let total_fat: f64 = nutrition.iter().map(|n| n.fat_g).sum();
        let total_carbs: f64 = nutrition.iter().map(|n| n.carbs_g).sum();

        Ok(NutritionAvgState {
            avg_calories: Some((total_calories / count).round()),
            avg_protein_g: Some((total_protein / count * 10.0).round() / 10.0),
            avg_fat_g: Some((total_fat / count * 10.0).round() / 10.0),
            avg_carbs_g: Some((total_carbs / count * 10.0).round() / 10.0),
            days_logged: nutrition.len() as i32,
        })
    }
}

/// Calculate estimated 1RM using Epley formula
/// e1rm = weight * (1 + reps/30)
/// Only valid for reps 1-12
pub fn calculate_e1rm(weight: f64, reps: i32) -> f64 {
    if reps <= 0 || reps > 12 {
        return weight;
    }
    let e1rm = weight * (1.0 + reps as f64 / 30.0);
    (e1rm * 100.0).round() / 100.0
}

/// System instruction for Gemini AI
pub fn get_system_instruction(state: &UserState) -> String {
    format!(
        r#"
あなたはパーソナルトレーニングコーチ「ガチトレAI」です。
ユーザーの目標達成を最優先に、科学的根拠に基づいたアドバイスを提供してください。

【ユーザー情報】
- 目標: {}
- レベル: {}
- 身長: {}cm
- 制約: {:?}

【重要なルール】
1. 医学的な診断や治療の提案は絶対にしない
2. 極端なカロリー制限（基礎代謝以下）は推奨しない
3. 怪我のリスクがある場合は必ず警告する
4. 回答は必ず以下のJSON形式で返す

【出力フォーマット】
{{
  "answer_text": "ユーザーへの回答テキスト（マークダウン形式可）",
  "recommendations": [
    {{"kind": "workout|nutrition|recovery|supplement", "payload": {{...}}}}
  ],
  "warnings": ["該当する場合のみ警告メッセージ"]
}}

【kind別のpayloadの例】
- workout: {{"exercises": [...], "sets": 3, "reps": "8-12", "rest_sec": 90}}
- nutrition: {{"meal_type": "post_workout", "foods": [...], "macros": {{...}}}}
- recovery: {{"type": "rest|deload|stretch", "duration_days": 1}}

日本語で回答してください。
"#,
        state.profile.goal,
        state.profile.training_level,
        state.profile.height_cm.map(|h| h.to_string()).unwrap_or("不明".to_string()),
        state.profile.constraints
    )
}

/// Safety guard - check for dangerous advice requests
pub fn check_safety_flags(message: &str) -> Vec<String> {
    let mut flags = Vec::new();

    let dangerous_keywords = [
        ("ステロイド", "steroids"),
        ("アナボリック", "anabolics"),
        ("断食", "extreme_fasting"),
        ("500kcal以下", "extreme_calorie_restriction"),
        ("怪我を無視", "ignoring_injury"),
        ("痛みがあるけど", "training_with_pain"),
    ];

    let message_lower = message.to_lowercase();

    for (jp, flag) in &dangerous_keywords {
        if message_lower.contains(jp) {
            flags.push(flag.to_string());
        }
    }

    flags
}
