use axum::{
    extract::{Query, State},
    Extension, Json,
};
use serde::{Deserialize, Serialize};

use crate::{
    api::middleware::AuthUser,
    error::AppResult,
    AppState,
};

// =============================================================================
// Request/Response DTOs
// =============================================================================

#[derive(Debug, Deserialize)]
pub struct DateQuery {
    pub date: Option<String>,  // YYYY-MM-DD, defaults to today
}

#[derive(Debug, Serialize)]
pub struct DashboardResponse {
    pub date: String,
    pub body_metrics: Option<BodyMetricsData>,
    pub nutrition: Option<NutritionData>,
    pub workout_count: i32,
    pub tasks: TasksData,
}

#[derive(Debug, Serialize)]
pub struct BodyMetricsData {
    pub weight_kg: Option<f64>,
    pub bodyfat_pct: Option<f64>,
    pub sleep_hours: Option<f64>,
    pub steps: Option<i32>,
}

#[derive(Debug, Serialize)]
pub struct NutritionData {
    pub calories: i32,
    pub protein_g: f64,
    pub fat_g: f64,
    pub carbs_g: f64,
    pub meals_logged: i32,
}

#[derive(Debug, Serialize)]
pub struct TasksData {
    pub weight_logged: bool,
    pub meals_completed: bool,
    pub meals_target: i32,
    pub meals_logged: i32,
    pub workout_logged: bool,
}

#[derive(Debug, Deserialize)]
pub struct LogMetricsRequest {
    pub date: String,
    pub weight_kg: Option<f64>,
    pub bodyfat_pct: Option<f64>,
    pub sleep_hours: Option<f64>,
    pub steps: Option<i32>,
}

#[derive(Debug, Serialize)]
pub struct MessageResponse {
    pub message: String,
}

// =============================================================================
// Handlers
// =============================================================================

/// GET /dashboard/today - Get dashboard data for today or specific date
pub async fn get_dashboard(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Query(params): Query<DateQuery>,
) -> AppResult<Json<DashboardResponse>> {
    let today = params.date.unwrap_or_else(|| {
        chrono::Utc::now().format("%Y-%m-%d").to_string()
    });

    // Get body metrics for today
    let metrics_query = format!(
        "user_id=eq.{}&date=eq.{}&select=weight_kg,bodyfat_pct,sleep_hours,steps",
        user.user_id, today
    );
    let metrics: Vec<serde_json::Value> = state
        .supabase
        .select("body_metrics", &metrics_query, &user.token)
        .await?;
    let metric_data = metrics.into_iter().next();

    let body_metrics = metric_data.as_ref().map(|m| BodyMetricsData {
        weight_kg: m["weight_kg"].as_f64(),
        bodyfat_pct: m["bodyfat_pct"].as_f64(),
        sleep_hours: m["sleep_hours"].as_f64(),
        steps: m["steps"].as_i64().map(|v| v as i32),
    });

    // Get nutrition for today
    let nutrition_query = format!(
        "user_id=eq.{}&date=eq.{}&select=calories,protein_g,fat_g,carbs_g,meals_logged",
        user.user_id, today
    );
    let nutrition_result: Vec<serde_json::Value> = state
        .supabase
        .select("nutrition_daily", &nutrition_query, &user.token)
        .await?;
    let nutrition_data = nutrition_result.into_iter().next();

    let nutrition = nutrition_data.as_ref().map(|n| NutritionData {
        calories: n["calories"].as_i64().unwrap_or(0) as i32,
        protein_g: n["protein_g"].as_f64().unwrap_or(0.0),
        fat_g: n["fat_g"].as_f64().unwrap_or(0.0),
        carbs_g: n["carbs_g"].as_f64().unwrap_or(0.0),
        meals_logged: n["meals_logged"].as_i64().unwrap_or(0) as i32,
    });

    // Get workout count for today
    let workout_query = format!(
        "user_id=eq.{}&date=eq.{}&select=id",
        user.user_id, today
    );
    let workouts: Vec<serde_json::Value> = state
        .supabase
        .select("workouts", &workout_query, &user.token)
        .await?;
    let workout_count = workouts.len() as i32;

    // Get user's meals_per_day setting
    let profile_query = format!(
        "user_id=eq.{}&select=meals_per_day",
        user.user_id
    );
    let profiles: Vec<serde_json::Value> = state
        .supabase
        .select("user_profiles", &profile_query, &user.token)
        .await?;
    let meals_target = profiles
        .into_iter()
        .next()
        .and_then(|p| p["meals_per_day"].as_i64())
        .unwrap_or(3) as i32;

    let meals_logged = nutrition.as_ref().map(|n| n.meals_logged).unwrap_or(0);

    let tasks = TasksData {
        weight_logged: body_metrics.as_ref().and_then(|m| m.weight_kg).is_some(),
        meals_completed: meals_logged >= meals_target,
        meals_target,
        meals_logged,
        workout_logged: workout_count > 0,
    };

    Ok(Json(DashboardResponse {
        date: today,
        body_metrics,
        nutrition,
        workout_count,
        tasks,
    }))
}

/// POST /log/metrics - Log body metrics (weight, bodyfat, sleep, steps)
pub async fn log_metrics(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Json(req): Json<LogMetricsRequest>,
) -> AppResult<Json<MessageResponse>> {
    // Check if metrics already exist for this date
    let check_query = format!(
        "user_id=eq.{}&date=eq.{}",
        user.user_id, req.date
    );
    let existing: Vec<serde_json::Value> = state
        .supabase
        .select("body_metrics", &check_query, &user.token)
        .await?;

    if existing.is_empty() {
        // Insert new record
        let data = serde_json::json!({
            "user_id": user.user_id,
            "date": req.date,
            "weight_kg": req.weight_kg,
            "bodyfat_pct": req.bodyfat_pct,
            "sleep_hours": req.sleep_hours,
            "steps": req.steps
        });

        let _: serde_json::Value = state
            .supabase
            .insert("body_metrics", &data, &user.token)
            .await?;
    } else {
        // Update existing record
        let update_data = serde_json::json!({
            "weight_kg": req.weight_kg,
            "bodyfat_pct": req.bodyfat_pct,
            "sleep_hours": req.sleep_hours,
            "steps": req.steps
        });

        state
            .supabase
            .update("body_metrics", &check_query, &update_data, &user.token)
            .await?;
    }

    Ok(Json(MessageResponse {
        message: "Metrics logged successfully".to_string(),
    }))
}

