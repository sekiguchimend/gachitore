use serde::{Deserialize, Serialize};

// =============================================================================
// Data models for Supabase responses
// =============================================================================

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserProfile {
    pub user_id: String,
    pub display_name: String,
    pub sex: Option<String>,
    pub birth_year: Option<i32>,
    pub height_cm: Option<i32>,
    pub training_level: String,
    pub goal: String,
    pub environment: Option<serde_json::Value>,
    pub constraints: Option<serde_json::Value>,
    pub meals_per_day: Option<i32>,
    pub onboarding_completed: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BodyMetrics {
    pub id: String,
    pub user_id: String,
    pub date: String,
    pub weight_kg: Option<f64>,
    pub bodyfat_pct: Option<f64>,
    pub sleep_hours: Option<f64>,
    pub steps: Option<i32>,
    pub note: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NutritionDaily {
    pub id: String,
    pub user_id: String,
    pub date: String,
    pub calories: i32,
    pub protein_g: f64,
    pub fat_g: f64,
    pub carbs_g: f64,
    pub fiber_g: Option<f64>,
    pub meals_logged: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Workout {
    pub id: String,
    pub user_id: String,
    pub date: String,
    pub start_time: Option<String>,
    pub end_time: Option<String>,
    pub perceived_fatigue: Option<i32>,
    pub note: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkoutExercise {
    pub id: String,
    pub workout_id: String,
    pub exercise_id: Option<String>,
    pub custom_exercise_name: Option<String>,
    pub muscle_tag: String,
    pub exercise_order: i32,
    pub note: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WorkoutSet {
    pub id: String,
    pub workout_exercise_id: String,
    pub set_index: i32,
    pub weight_kg: Option<f64>,
    pub reps: Option<i32>,
    pub rpe: Option<f64>,
    pub rest_sec: Option<i32>,
    pub tempo: Option<String>,
    pub is_warmup: bool,
    pub is_dropset: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AiSession {
    pub id: String,
    pub user_id: String,
    pub intent: String,
    pub state_version: String,
    pub model: String,
    pub input_summary: Option<serde_json::Value>,
    pub safety_flags: serde_json::Value,
    pub created_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AiMessage {
    pub id: String,
    pub session_id: String,
    pub role: String,
    pub content: String,
    pub created_at: String,
}

/// 掲示板の投稿
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Post {
    pub id: String,
    pub user_id: String,
    pub content: String,
    pub image_path: Option<String>,
    pub created_at: String,
}



