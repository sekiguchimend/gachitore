use axum::{
    extract::{rejection::JsonRejection, State},
    Extension, Json,
};
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
    // Must match DB constraint in public.user_profiles.goal
    const ALLOWED_GOALS: &[&str] = &["hypertrophy", "cut", "health", "strength"];
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
    pub target_calories: Option<i32>,
    pub target_protein_g: Option<f64>,
    pub target_fat_g: Option<f64>,
    pub target_carbs_g: Option<f64>,
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
    pub target_calories: Option<i32>,
    pub target_protein_g: Option<f64>,
    pub target_fat_g: Option<f64>,
    pub target_carbs_g: Option<f64>,
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
pub enum CompleteOnboardingRequest {
    /// Legacy client payload
    V1 {
        goal: String,
        level: String,
        weight: f64,
        height: f64,
        age: i32,
        sex: String,
        environment: Option<String>,
        constraints: Option<Vec<String>>,
    },
    /// Newer client payload aligned to DB column names (Flutter sends this)
    V2 {
        goal: String,
        training_level: String,
        /// Optional: some clients may forget to send weight_kg (we’ll accept but skip body_metrics)
        #[serde(default)]
        weight_kg: Option<f64>,
        height_cm: i32,
        birth_year: i32,
        sex: String,
        environment: Option<serde_json::Value>,
        constraints: Option<serde_json::Value>,
        #[serde(default)]
        meals_per_day: Option<i32>,
    },
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
        target_calories: profile.as_ref().and_then(|p| p["target_calories"].as_i64().map(|v| v as i32)),
        target_protein_g: profile.as_ref().and_then(|p| p["target_protein_g"].as_f64()),
        target_fat_g: profile.as_ref().and_then(|p| p["target_fat_g"].as_f64()),
        target_carbs_g: profile.as_ref().and_then(|p| p["target_carbs_g"].as_f64()),
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
    payload: Result<Json<CompleteOnboardingRequest>, JsonRejection>,
) -> AppResult<Json<MessageResponse>> {
    let Json(req) = payload.map_err(|e| {
        AppError::BadRequest(format!(
            "onboarding/complete のリクエスト形式が不正です: {}",
            e
        ))
    })?;

    // Normalize request into internal fields
    let now = chrono::Utc::now();
    let today = now.format("%Y-%m-%d").to_string();
    let current_year = now.year();

    let (goal, training_level, sex, height_cm, birth_year, weight_kg, environment_json, constraints_json, meals_per_day) =
        match req {
            CompleteOnboardingRequest::V1 {
                goal,
                level,
                weight,
                height,
                age,
                sex,
                environment,
                constraints,
            } => {
                // Validate V1 fields
                validate_goal(&goal)?;
                validate_level(&level)?;
                validate_sex(&sex)?;
                validate_range(weight, 20.0, 300.0, "weight")?;
                validate_range(height, 50.0, 250.0, "height")?;
                validate_range(age, 1, 120, "age")?;

                let birth_year = current_year - age;

                // Build environment JSON based on the environment string
                let env = environment.as_deref().unwrap_or("gym");
                let environment_json = serde_json::json!({
                    "gym": env == "gym" || env == "both",
                    "home": env == "home" || env == "both",
                    "equipment": []  // Can be populated later
                });

                // Build constraints JSON array
                let constraints_json: serde_json::Value = constraints
                    .as_ref()
                    .map(|c| {
                        c.iter()
                            .map(|part| serde_json::json!({"part": part, "severity": "mild"}))
                            .collect::<Vec<_>>()
                    })
                    .map(serde_json::Value::Array)
                    .unwrap_or_else(|| serde_json::json!([]));

                (
                    goal,
                    level,
                    sex,
                    height as i32,
                    birth_year,
                    Some(weight),
                    environment_json,
                    constraints_json,
                    3,
                )
            }
            CompleteOnboardingRequest::V2 {
                goal,
                training_level,
                weight_kg,
                height_cm,
                birth_year,
                sex,
                environment,
                constraints,
                meals_per_day,
            } => {
                // Validate V2 fields
                validate_goal(&goal)?;
                validate_level(&training_level)?;
                validate_sex(&sex)?;
                validate_range(height_cm, 50, 250, "height_cm")?;
                validate_range(birth_year, 1900, current_year, "birth_year")?;
                if let Some(w) = weight_kg {
                    validate_range(w, 20.0, 300.0, "weight_kg")?;
                }

                let environment_json = environment.unwrap_or_else(|| serde_json::json!({}));
                let constraints_json = constraints.unwrap_or_else(|| serde_json::json!([]));
                let meals_per_day = meals_per_day.unwrap_or(3);

                (
                    goal,
                    training_level,
                    sex,
                    height_cm,
                    birth_year,
                    weight_kg,
                    environment_json,
                    constraints_json,
                    meals_per_day,
                )
            }
        };

    // Upsert user profile (insert or update on conflict)
    let profile_data = serde_json::json!({
        "user_id": user.user_id,
        "display_name": user.email.split('@').next().unwrap_or("User"),
        "goal": goal,
        "training_level": training_level,
        "sex": sex,
        "height_cm": height_cm,
        "birth_year": birth_year,
        "environment": environment_json,
        "constraints": constraints_json,
        "meals_per_day": meals_per_day,
        "onboarding_completed": true,
        "updated_at": now.to_rfc3339()
    });

    state
        .supabase
        .upsert("user_profiles", &profile_data, "user_id", &user.token)
        .await?;

    // Upsert body metrics (weight only - height is in user_profiles)
    if let Some(weight_kg) = weight_kg {
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

    // Validate PFC targets (optional)
    if let Some(cal) = req.target_calories {
        validate_range(cal, 500, 10000, "target_calories")?;
    }
    if let Some(p) = req.target_protein_g {
        validate_range(p, 0.0, 1000.0, "target_protein_g")?;
    }
    if let Some(f) = req.target_fat_g {
        validate_range(f, 0.0, 500.0, "target_fat_g")?;
    }
    if let Some(c) = req.target_carbs_g {
        validate_range(c, 0.0, 1000.0, "target_carbs_g")?;
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
        if let Some(target_calories) = req.target_calories {
            profile_updates.insert("target_calories".to_string(), serde_json::json!(target_calories));
        }
        if let Some(target_protein_g) = req.target_protein_g {
            profile_updates.insert("target_protein_g".to_string(), serde_json::json!(target_protein_g));
        }
        if let Some(target_fat_g) = req.target_fat_g {
            profile_updates.insert("target_fat_g".to_string(), serde_json::json!(target_fat_g));
        }
        if let Some(target_carbs_g) = req.target_carbs_g {
            profile_updates.insert("target_carbs_g".to_string(), serde_json::json!(target_carbs_g));
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
            "target_calories": req.target_calories.unwrap_or(2400),
            "target_protein_g": req.target_protein_g.unwrap_or(150.0),
            "target_fat_g": req.target_fat_g.unwrap_or(80.0),
            "target_carbs_g": req.target_carbs_g.unwrap_or(250.0),
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
