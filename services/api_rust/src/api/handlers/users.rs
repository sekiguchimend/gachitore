use axum::{extract::State, Extension, Json};
use chrono::Datelike;
use serde::{Deserialize, Serialize};

use crate::{
    api::middleware::AuthUser,
    error::{AppError, AppResult},
    AppState,
};

// =============================================================================
// Validation Helpers
// =============================================================================

/// Validate goal is one of allowed values
fn validate_goal(goal: &str) -> Result<(), AppError> {
    const ALLOWED_GOALS: &[&str] = &["muscle_gain", "fat_loss", "health", "endurance", "strength"];
    if ALLOWED_GOALS.contains(&goal.to_lowercase().as_str()) {
        Ok(())
    } else {
        Err(AppError::Validation(format!(
            "Invalid goal. Allowed: {:?}",
            ALLOWED_GOALS
        )))
    }
}

/// Validate training level is one of allowed values
fn validate_level(level: &str) -> Result<(), AppError> {
    const ALLOWED_LEVELS: &[&str] = &["beginner", "intermediate", "advanced"];
    if ALLOWED_LEVELS.contains(&level.to_lowercase().as_str()) {
        Ok(())
    } else {
        Err(AppError::Validation(format!(
            "Invalid level. Allowed: {:?}",
            ALLOWED_LEVELS
        )))
    }
}

/// Validate sex is one of allowed values
fn validate_sex(sex: &str) -> Result<(), AppError> {
    const ALLOWED_SEX: &[&str] = &["male", "female", "other"];
    if ALLOWED_SEX.contains(&sex.to_lowercase().as_str()) {
        Ok(())
    } else {
        Err(AppError::Validation(format!(
            "Invalid sex. Allowed: {:?}",
            ALLOWED_SEX
        )))
    }
}

/// Validate numeric range for physical attributes
fn validate_range<T: PartialOrd + std::fmt::Display>(
    value: T,
    min: T,
    max: T,
    field: &str,
) -> Result<(), AppError> {
    if value < min || value > max {
        Err(AppError::Validation(format!(
            "{} must be between {} and {}",
            field, min, max
        )))
    } else {
        Ok(())
    }
}

// =============================================================================
// Update Profile Request
// =============================================================================

#[derive(Debug, Deserialize)]
pub struct UpdateProfileRequest {
    pub display_name: Option<String>,
    pub goal: Option<String>,
    pub training_level: Option<String>,
    pub sex: Option<String>,
    pub height_cm: Option<i32>,
    pub birth_year: Option<i32>,
    pub weight_kg: Option<f64>,
    pub environment: Option<serde_json::Value>,
    pub constraints: Option<serde_json::Value>,
}

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
    // Validate all inputs
    validate_goal(&req.goal)?;
    validate_level(&req.level)?;
    validate_sex(&req.sex)?;
    validate_range(req.weight, 20.0, 300.0, "weight")?;
    validate_range(req.height, 50.0, 250.0, "height")?;
    validate_range(req.age, 1, 120, "age")?;

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

/// PATCH /users/profile
pub async fn update_profile(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Json(req): Json<UpdateProfileRequest>,
) -> AppResult<Json<MessageResponse>> {
    // Validate optional fields if provided
    if let Some(ref goal) = req.goal {
        validate_goal(goal)?;
    }
    if let Some(ref level) = req.training_level {
        validate_level(level)?;
    }
    if let Some(ref sex) = req.sex {
        validate_sex(sex)?;
    }
    if let Some(height) = req.height_cm {
        validate_range(height, 50, 250, "height_cm")?;
    }
    if let Some(weight) = req.weight_kg {
        validate_range(weight, 20.0, 300.0, "weight_kg")?;
    }
    if let Some(birth_year) = req.birth_year {
        let current_year = chrono::Utc::now().year();
        validate_range(birth_year, 1900, current_year, "birth_year")?;
    }
    if let Some(ref name) = req.display_name {
        if name.len() > 100 {
            return Err(AppError::Validation("display_name is too long (max 100 chars)".to_string()));
        }
    }

    let now = chrono::Utc::now();
    let today = now.format("%Y-%m-%d").to_string();

    // If profile row doesn't exist yet, UPSERT becomes an INSERT and must satisfy NOT NULL columns.
    // So: existing -> UPDATE (partial), missing -> UPSERT with required defaults.
    let existing_profile: Option<serde_json::Value> = state
        .supabase
        .select_single(
            "user_profiles",
            &format!("user_id=eq.{}&select=user_id", user.user_id),
            &user.token,
        )
        .await?;

    if existing_profile.is_some() {
        // Partial update only (safe even when display_name is not provided)
        let mut profile_updates = serde_json::Map::new();
        profile_updates.insert("updated_at".to_string(), serde_json::json!(now.to_rfc3339()));

        if let Some(display_name) = &req.display_name {
            profile_updates.insert("display_name".to_string(), serde_json::json!(display_name));
        }
        if let Some(goal) = &req.goal {
            profile_updates.insert("goal".to_string(), serde_json::json!(goal));
        }
        if let Some(training_level) = &req.training_level {
            profile_updates.insert("training_level".to_string(), serde_json::json!(training_level));
        }
        if let Some(sex) = &req.sex {
            profile_updates.insert("sex".to_string(), serde_json::json!(sex));
        }
        if let Some(height_cm) = req.height_cm {
            profile_updates.insert("height_cm".to_string(), serde_json::json!(height_cm));
        }
        if let Some(birth_year) = req.birth_year {
            profile_updates.insert("birth_year".to_string(), serde_json::json!(birth_year));
        }
        if let Some(environment) = &req.environment {
            profile_updates.insert("environment".to_string(), environment.clone());
        }
        if let Some(constraints) = &req.constraints {
            profile_updates.insert("constraints".to_string(), constraints.clone());
        }

        let profile_data = serde_json::Value::Object(profile_updates);
        state
            .supabase
            .update(
                "user_profiles",
                &format!("user_id=eq.{}", user.user_id),
                &profile_data,
                &user.token,
            )
            .await?;
    } else {
        // Create minimal profile row with required defaults
        let display_name_default = user.email.split('@').next().unwrap_or("User");

        let profile_data = serde_json::json!({
            "user_id": user.user_id,
            "display_name": req.display_name.as_deref().unwrap_or(display_name_default),
            "goal": req.goal.as_deref().unwrap_or("health"),
            "training_level": req.training_level.as_deref().unwrap_or("beginner"),
            "sex": req.sex,
            "height_cm": req.height_cm,
            "birth_year": req.birth_year,
            "environment": req.environment.unwrap_or_else(|| serde_json::json!({})),
            "constraints": req.constraints.unwrap_or_else(|| serde_json::json!([])),
            "meals_per_day": 3,
            "onboarding_completed": false,
            "updated_at": now.to_rfc3339(),
        });

        state
            .supabase
            .upsert("user_profiles", &profile_data, "user_id", &user.token)
            .await?;
    }

    // If weight is provided, also update body_metrics
    if let Some(weight_kg) = req.weight_kg {
        let metrics_data = serde_json::json!({
            "user_id": user.user_id,
            "date": today,
            "weight_kg": weight_kg
        });

        state
            .supabase
            .upsert("body_metrics", &metrics_data, "user_id,date", &user.token)
            .await?;
    }

    Ok(Json(MessageResponse {
        message: "Profile updated successfully".to_string(),
    }))
}
