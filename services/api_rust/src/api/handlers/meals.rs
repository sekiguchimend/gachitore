use axum::{
    extract::{Path, Query, State},
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
    pub date: String, // YYYY-MM-DD
}

#[derive(Debug, Serialize)]
pub struct MealEntry {
    pub id: String,
    pub date: String,
    pub time: Option<String>,
    pub meal_type: String,
    pub note: Option<String>,
    pub items: Vec<MealItem>,
}

#[derive(Debug, Serialize)]
pub struct MealItem {
    pub id: String,
    pub name: String,
    pub quantity: Option<f64>,
    pub unit: Option<String>,
    pub calories: i32,
    pub protein_g: f64,
    pub fat_g: f64,
    pub carbs_g: f64,
}

#[derive(Debug, Serialize)]
pub struct NutritionSummary {
    pub calories: i32,
    pub calories_goal: i32,
    pub protein: i32,
    pub protein_goal: i32,
    pub fat: i32,
    pub fat_goal: i32,
    pub carbs: i32,
    pub carbs_goal: i32,
}

#[derive(Debug, Serialize)]
pub struct MessageResponse {
    pub message: String,
}

// =============================================================================
// Handlers
// =============================================================================

/// GET /meals?date=YYYY-MM-DD
pub async fn get_meals(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Query(params): Query<DateQuery>,
) -> AppResult<Json<Vec<MealEntry>>> {
    let query = format!(
        "user_id=eq.{}&date=eq.{}&select=id,date,time,meal_type,note,meal_items(id,name,quantity,unit,calories,protein_g,fat_g,carbs_g)&order=time",
        user.user_id, params.date
    );

    let meals: Vec<serde_json::Value> = state
        .supabase
        .select("meals", &query, &user.token)
        .await?;

    let result: Vec<MealEntry> = meals
        .into_iter()
        .map(|m| {
            let items = m["meal_items"]
                .as_array()
                .map(|arr| {
                    arr.iter()
                        .map(|i| MealItem {
                            id: i["id"].as_str().unwrap_or_default().to_string(),
                            name: i["name"].as_str().unwrap_or_default().to_string(),
                            quantity: i["quantity"].as_f64(),
                            unit: i["unit"].as_str().map(String::from),
                            calories: i["calories"].as_i64().unwrap_or(0) as i32,
                            protein_g: i["protein_g"].as_f64().unwrap_or(0.0),
                            fat_g: i["fat_g"].as_f64().unwrap_or(0.0),
                            carbs_g: i["carbs_g"].as_f64().unwrap_or(0.0),
                        })
                        .collect()
                })
                .unwrap_or_default();

            MealEntry {
                id: m["id"].as_str().unwrap_or_default().to_string(),
                date: m["date"].as_str().unwrap_or_default().to_string(),
                time: m["time"].as_str().map(String::from),
                meal_type: m["meal_type"].as_str().unwrap_or_default().to_string(),
                note: m["note"].as_str().map(String::from),
                items,
            }
        })
        .collect();

    Ok(Json(result))
}

/// GET /meals/nutrition?date=YYYY-MM-DD
pub async fn get_nutrition(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Query(params): Query<DateQuery>,
) -> AppResult<Json<NutritionSummary>> {
    // Get daily nutrition
    let nutrition_query = format!(
        "user_id=eq.{}&date=eq.{}",
        user.user_id, params.date
    );
    let nutrition: Vec<serde_json::Value> = state
        .supabase
        .select("nutrition_daily", &nutrition_query, &user.token)
        .await?;

    let nutrition_data = nutrition.into_iter().next();

    // Get user goals from profile
    let profile_query = format!(
        "user_id=eq.{}&select=target_calories,target_protein_g,target_fat_g,target_carbs_g",
        user.user_id
    );
    let profiles: Vec<serde_json::Value> = state
        .supabase
        .select("user_profiles", &profile_query, &user.token)
        .await?;

    let goals = profiles.into_iter().next();

    Ok(Json(NutritionSummary {
        calories: nutrition_data.as_ref().and_then(|n| n["calories"].as_i64()).unwrap_or(0) as i32,
        calories_goal: goals.as_ref().and_then(|g| g["target_calories"].as_i64()).unwrap_or(2400) as i32,
        protein: nutrition_data.as_ref().and_then(|n| n["protein_g"].as_f64()).unwrap_or(0.0).round() as i32,
        protein_goal: goals.as_ref().and_then(|g| g["target_protein_g"].as_f64()).unwrap_or(150.0).round() as i32,
        fat: nutrition_data.as_ref().and_then(|n| n["fat_g"].as_f64()).unwrap_or(0.0).round() as i32,
        fat_goal: goals.as_ref().and_then(|g| g["target_fat_g"].as_f64()).unwrap_or(80.0).round() as i32,
        carbs: nutrition_data.as_ref().and_then(|n| n["carbs_g"].as_f64()).unwrap_or(0.0).round() as i32,
        carbs_goal: goals.as_ref().and_then(|g| g["target_carbs_g"].as_f64()).unwrap_or(250.0).round() as i32,
    }))
}

/// DELETE /meals/:id
pub async fn delete_meal(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Path(meal_id): Path<String>,
) -> AppResult<Json<MessageResponse>> {
    let query = format!("id=eq.{}&user_id=eq.{}", meal_id, user.user_id);

    state
        .supabase
        .delete("meals", &query, &user.token)
        .await?;

    Ok(Json(MessageResponse {
        message: "Meal deleted successfully".to_string(),
    }))
}
