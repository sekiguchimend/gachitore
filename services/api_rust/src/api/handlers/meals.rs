use axum::{
    extract::{Path, Query, State},
    Extension, Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

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

#[derive(Debug, Deserialize)]
pub struct LogMealRequest {
    pub date: String,
    pub time: Option<String>,
    pub meal_type: String,
    pub meal_index: Option<i32>,
    pub note: Option<String>,
    pub photo_url: Option<String>,
    pub items: Vec<LogMealItemRequest>,
}

#[derive(Debug, Deserialize)]
pub struct LogMealItemRequest {
    pub name: String,
    pub quantity: Option<f64>,
    pub unit: Option<String>,
    pub calories: Option<i32>,
    pub protein_g: Option<f64>,
    pub fat_g: Option<f64>,
    pub carbs_g: Option<f64>,
    pub fiber_g: Option<f64>,
}

#[derive(Debug, Serialize)]
pub struct LogMealResponse {
    pub meal_id: String,
    pub message: String,
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

/// POST /log/meal - Log a meal
pub async fn log_meal(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Json(req): Json<LogMealRequest>,
) -> AppResult<Json<LogMealResponse>> {
    let meal_id = Uuid::new_v4().to_string();

    // Insert meal
    let meal_data = serde_json::json!({
        "id": meal_id,
        "user_id": user.user_id,
        "date": req.date,
        "time": req.time,
        "meal_type": req.meal_type,
        "meal_index": req.meal_index.unwrap_or(1),
        "note": req.note,
        "photo_url": req.photo_url
    });

    let _: serde_json::Value = state
        .supabase
        .insert("meals", &meal_data, &user.token)
        .await?;

    // Insert meal items
    let mut total_calories = 0i32;
    let mut total_protein = 0.0f64;
    let mut total_fat = 0.0f64;
    let mut total_carbs = 0.0f64;
    let mut total_fiber = 0.0f64;

    for item in &req.items {
        let item_data = serde_json::json!({
            "id": Uuid::new_v4().to_string(),
            "meal_id": meal_id,
            "name": item.name,
            "quantity": item.quantity.unwrap_or(1.0),
            "unit": item.unit.clone().unwrap_or_else(|| "serving".to_string()),
            "calories": item.calories.unwrap_or(0),
            "protein_g": item.protein_g.unwrap_or(0.0),
            "fat_g": item.fat_g.unwrap_or(0.0),
            "carbs_g": item.carbs_g.unwrap_or(0.0),
            "fiber_g": item.fiber_g.unwrap_or(0.0)
        });

        let _: serde_json::Value = state
            .supabase
            .insert("meal_items", &item_data, &user.token)
            .await?;

        // Accumulate totals
        total_calories += item.calories.unwrap_or(0);
        total_protein += item.protein_g.unwrap_or(0.0);
        total_fat += item.fat_g.unwrap_or(0.0);
        total_carbs += item.carbs_g.unwrap_or(0.0);
        total_fiber += item.fiber_g.unwrap_or(0.0);
    }

    // Update or insert nutrition_daily
    let nutrition_query = format!(
        "user_id=eq.{}&date=eq.{}",
        user.user_id, req.date
    );
    let existing_nutrition: Vec<serde_json::Value> = state
        .supabase
        .select("nutrition_daily", &nutrition_query, &user.token)
        .await?;

    if let Some(existing) = existing_nutrition.into_iter().next() {
        // Update existing
        let new_calories = existing["calories"].as_i64().unwrap_or(0) as i32 + total_calories;
        let new_protein = existing["protein_g"].as_f64().unwrap_or(0.0) + total_protein;
        let new_fat = existing["fat_g"].as_f64().unwrap_or(0.0) + total_fat;
        let new_carbs = existing["carbs_g"].as_f64().unwrap_or(0.0) + total_carbs;
        let new_fiber = existing["fiber_g"].as_f64().unwrap_or(0.0) + total_fiber;
        let new_meals = existing["meals_logged"].as_i64().unwrap_or(0) as i32 + 1;

        let update_data = serde_json::json!({
            "calories": new_calories,
            "protein_g": new_protein,
            "fat_g": new_fat,
            "carbs_g": new_carbs,
            "fiber_g": new_fiber,
            "meals_logged": new_meals,
            "updated_at": chrono::Utc::now().to_rfc3339()
        });

        state
            .supabase
            .update("nutrition_daily", &nutrition_query, &update_data, &user.token)
            .await?;
    } else {
        // Insert new
        let nutrition_data = serde_json::json!({
            "user_id": user.user_id,
            "date": req.date,
            "calories": total_calories,
            "protein_g": total_protein,
            "fat_g": total_fat,
            "carbs_g": total_carbs,
            "fiber_g": total_fiber,
            "meals_logged": 1
        });

        let _: serde_json::Value = state
            .supabase
            .insert("nutrition_daily", &nutrition_data, &user.token)
            .await?;
    }

    Ok(Json(LogMealResponse {
        meal_id,
        message: "Meal logged successfully".to_string(),
    }))
}
