use axum::{extract::State, Extension, Json};
use chrono::Datelike;
use serde::{Deserialize, Serialize};

use crate::{
    api::middleware::AuthUser,
    error::AppResult,
    AppState,
};

// =============================================================================
// Request/Response DTOs
// =============================================================================

#[derive(Debug, Serialize, Deserialize)]
pub struct UserProfile {
    pub user_id: String,
    pub email: Option<String>,
    pub display_name: Option<String>,
    pub goal: Option<String>,
    pub training_level: Option<String>,
    pub sex: Option<String>,
    /// Environment as JSON: {"gym": true, "home": false, "equipment": ["dumbbell", "barbell"]}
    pub environment: Option<serde_json::Value>,
    /// Constraints as JSON array: [{"part": "shoulder", "severity": "mild"}]
    pub constraints: Option<serde_json::Value>,
    pub onboarding_completed: bool,
    pub weight_kg: Option<f64>,
    pub height_cm: Option<i32>,
    pub birth_year: Option<i32>,
}

#[derive(Debug, Deserialize)]
pub struct CompleteOnboardingRequest {
    pub goal: String,
    pub level: String,
    pub weight: f64,
    pub height: f64,
    pub age: i32,
    pub sex: String,
    pub environment: Option<String>,
    pub constraints: Option<Vec<String>>,
}

#[derive(Debug, Serialize)]
pub struct OnboardingStatusResponse {
    pub completed: bool,
}

#[derive(Debug, Serialize)]
pub struct MessageResponse {
    pub message: String,
}

// =============================================================================
// Handlers
// =============================================================================

/// GET /users/profile
pub async fn get_profile(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
) -> AppResult<Json<UserProfile>> {
    // Get profile
    let profile_query = format!("user_id=eq.{}", user.user_id);
    let profiles: Vec<serde_json::Value> = state
        .supabase
        .select("user_profiles", &profile_query, &user.token)
        .await?;

    let profile = profiles.into_iter().next();

    // Get latest body metrics
    let metrics_query = format!(
        "user_id=eq.{}&order=date.desc&limit=1",
        user.user_id
    );
    let metrics: Vec<serde_json::Value> = state
        .supabase
        .select("body_metrics", &metrics_query, &user.token)
        .await?;

    let metric = metrics.into_iter().next();

    Ok(Json(UserProfile {
        user_id: user.user_id.clone(),
        email: Some(user.email.clone()),
        display_name: profile.as_ref().and_then(|p| p["display_name"].as_str().map(String::from)),
        goal: profile.as_ref().and_then(|p| p["goal"].as_str().map(String::from)),
        training_level: profile.as_ref().and_then(|p| p["training_level"].as_str().map(String::from)),
        sex: profile.as_ref().and_then(|p| p["sex"].as_str().map(String::from)),
        environment: profile.as_ref().and_then(|p| p.get("environment").cloned()),
        constraints: profile.as_ref().and_then(|p| p.get("constraints").cloned()),
        onboarding_completed: profile.as_ref().and_then(|p| p["onboarding_completed"].as_bool()).unwrap_or(false),
        weight_kg: metric.as_ref().and_then(|m| m["weight_kg"].as_f64()),
        height_cm: profile.as_ref().and_then(|p| p["height_cm"].as_i64().map(|v| v as i32)),
        birth_year: profile.as_ref().and_then(|p| p["birth_year"].as_i64().map(|v| v as i32)),
    }))
}

/// GET /users/onboarding/status
pub async fn get_onboarding_status(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
) -> AppResult<Json<OnboardingStatusResponse>> {
    let query = format!(
        "user_id=eq.{}&select=onboarding_completed",
        user.user_id
    );
    let profiles: Vec<serde_json::Value> = state
        .supabase
        .select("user_profiles", &query, &user.token)
        .await?;

    let completed = profiles
        .into_iter()
        .next()
        .and_then(|p| p["onboarding_completed"].as_bool())
        .unwrap_or(false);

    Ok(Json(OnboardingStatusResponse { completed }))
}

/// POST /users/onboarding/complete
pub async fn complete_onboarding(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Json(req): Json<CompleteOnboardingRequest>,
) -> AppResult<Json<MessageResponse>> {
    let now = chrono::Utc::now();
    let today = now.format("%Y-%m-%d").to_string();
    
    // Calculate birth year from age
    let current_year = now.year();
    let birth_year = current_year - req.age;

    // Build environment JSON based on the environment string
    let env = req.environment.as_deref().unwrap_or("gym");
    let environment_json = serde_json::json!({
        "gym": env == "gym" || env == "both",
        "home": env == "home" || env == "both",
        "equipment": []  // Can be populated later
    });

    // Build constraints JSON array
    let constraints_json: serde_json::Value = req.constraints
        .as_ref()
        .map(|c| {
            c.iter()
                .map(|part| serde_json::json!({"part": part, "severity": "mild"}))
                .collect::<Vec<_>>()
        })
        .map(|arr| serde_json::Value::Array(arr))
        .unwrap_or(serde_json::json!([]));

    // Upsert user profile (insert or update on conflict)
    let profile_data = serde_json::json!({
        "user_id": user.user_id,
        "display_name": user.email.split('@').next().unwrap_or("User"),
        "goal": req.goal,
        "training_level": req.level,
        "sex": req.sex,
        "height_cm": req.height as i32,
        "birth_year": birth_year,
        "environment": environment_json,
        "constraints": constraints_json,
        "onboarding_completed": true,
        "updated_at": now.to_rfc3339()
    });

    state
        .supabase
        .upsert("user_profiles", &profile_data, "user_id", &user.token)
        .await?;

    // Upsert body metrics (weight only - height is in user_profiles)
    let metrics_data = serde_json::json!({
        "user_id": user.user_id,
        "date": today,
        "weight_kg": req.weight
    });

    state
        .supabase
        .upsert("body_metrics", &metrics_data, "user_id,date", &user.token)
        .await?;

    Ok(Json(MessageResponse {
        message: "Onboarding completed successfully".to_string(),
    }))
}
