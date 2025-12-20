use axum::{
    extract::{Path, Query, State},
    Extension, Json,
};
use chrono::NaiveDate;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    api::middleware::AuthUser,
    api::validation::{validate_date_ymd, validate_uuid},
    error::{AppError, AppResult},
    AppState,
};

// =============================================================================
// Validation Helpers
// =============================================================================

/// Validate meal_type is one of allowed values
fn validate_meal_type(meal_type: &str) -> Result<(), AppError> {
    // Keep in sync with DB CHECK constraint (sql.md / Supabase schema).
    const ALLOWED_TYPES: &[&str] = &[
        "breakfast",
        "lunch",
        "dinner",
        "snack",
        "pre_workout",
        "post_workout",
        "other",
    ];
    if ALLOWED_TYPES.contains(&meal_type.to_lowercase().as_str()) {
        Ok(())
    } else {
        Err(AppError::Validation(format!(
            "Invalid meal_type. Allowed: {:?}",
            ALLOWED_TYPES
        )))
    }
}

// =============================================================================
// Request/Response DTOs
// =============================================================================

#[derive(Debug, Deserialize)]
pub struct DateQuery {
    pub date: String, // YYYY-MM-DD
}

#[derive(Debug, Deserialize)]
pub struct RecentMealsQuery {
    pub limit: Option<i64>,
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
    // Validate date format to prevent injection
    let validated_date = validate_date_ymd(&params.date)?;

    let query = format!(
        "user_id=eq.{}&date=eq.{}&select=id,date,time,meal_type,note,meal_items(id,name,quantity,unit,calories,protein_g,fat_g,carbs_g)&order=time",
        user.user_id, validated_date.format("%Y-%m-%d")
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

/// GET /meals/recent?limit=N
pub async fn get_recent_meals(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Query(params): Query<RecentMealsQuery>,
) -> AppResult<Json<Vec<MealEntry>>> {
    let limit = params.limit.unwrap_or(30).clamp(1, 200);

    let query = format!(
        "user_id=eq.{}&select=id,date,time,meal_type,note,meal_items(id,name,quantity,unit,calories,protein_g,fat_g,carbs_g)&order=date.desc,time.desc&limit={}",
        user.user_id, limit
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
    // Validate date format to prevent injection
    let validated_date = validate_date_ymd(&params.date)?;

    // Get daily nutrition
    let nutrition_query = format!(
        "user_id=eq.{}&date=eq.{}",
        user.user_id, validated_date.format("%Y-%m-%d")
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
    // Validate UUID format to prevent injection
    let validated_id = validate_uuid(&meal_id)?;

    let query = format!("id=eq.{}&user_id=eq.{}", validated_id, user.user_id);

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
    // Validate date format
    let validated_date = validate_date_ymd(&req.date)?;

    // Validate meal_type
    validate_meal_type(&req.meal_type)?;

    // Validate meal items
    if req.items.is_empty() {
        return Err(AppError::Validation("At least one meal item is required".to_string()));
    }

    for (i, item) in req.items.iter().enumerate() {
        // Check for empty or whitespace-only name
        if item.name.trim().is_empty() {
            return Err(AppError::Validation(format!("Item {} name cannot be empty", i + 1)));
        }
        // Check character length
        if item.name.chars().count() > 200 {
            return Err(AppError::Validation(format!("Item {} name is too long (max 200 chars)", i + 1)));
        }
        // Security: Check byte length to prevent UTF-8 exploits (4 bytes per char max)
        if item.name.as_bytes().len() > 800 {
            return Err(AppError::Validation(format!("Item {} name exceeds byte limit", i + 1)));
        }
        if let Some(qty) = item.quantity {
            if qty < 0.0 {
                return Err(AppError::Validation(format!("Item {} quantity cannot be negative", i + 1)));
            }
        }
        if let Some(cal) = item.calories {
            if cal < 0 {
                return Err(AppError::Validation(format!("Item {} calories cannot be negative", i + 1)));
            }
        }
        if let Some(protein) = item.protein_g {
            if protein < 0.0 {
                return Err(AppError::Validation(format!("Item {} protein cannot be negative", i + 1)));
            }
        }
        if let Some(fat) = item.fat_g {
            if fat < 0.0 {
                return Err(AppError::Validation(format!("Item {} fat cannot be negative", i + 1)));
            }
        }
        if let Some(carbs) = item.carbs_g {
            if carbs < 0.0 {
                return Err(AppError::Validation(format!("Item {} carbs cannot be negative", i + 1)));
            }
        }
    }

    let meal_id = Uuid::new_v4().to_string();

    // Insert meal (use validated date)
    let date_str = validated_date.format("%Y-%m-%d").to_string();
    let meal_data = serde_json::json!({
        "id": meal_id,
        "user_id": user.user_id,
        "date": date_str,
        "time": req.time,
        "meal_type": req.meal_type.to_lowercase(),
        "meal_index": req.meal_index.unwrap_or(1),
        "note": req.note,
        "photo_url": req.photo_url
    });

    let _: serde_json::Value = state
        .supabase
        .insert("meals", &meal_data, &user.token)
        .await?;

    // Collect meal items for batch insert
    let mut item_data_list: Vec<serde_json::Value> = Vec::new();
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

        item_data_list.push(item_data);

        // Accumulate totals
        total_calories += item.calories.unwrap_or(0);
        total_protein += item.protein_g.unwrap_or(0.0);
        total_fat += item.fat_g.unwrap_or(0.0);
        total_carbs += item.carbs_g.unwrap_or(0.0);
        total_fiber += item.fiber_g.unwrap_or(0.0);
    }

    // Batch insert meal items (1 query instead of N)
    if let Err(e) = state
        .supabase
        .insert_batch("meal_items", &item_data_list, &user.token)
        .await
    {
        // Best-effort rollback: avoid leaving an empty meal row if item insert fails.
        // (We don't have a cross-table transaction via PostgREST here.)
        let rollback_query = format!("id=eq.{}&user_id=eq.{}", meal_id, user.user_id);
        let _ = state
            .supabase
            .delete("meals", &rollback_query, &user.token)
            .await;
        return Err(e);
    }

    // Update or insert nutrition_daily
    let nutrition_query = format!(
        "user_id=eq.{}&date=eq.{}",
        user.user_id, date_str
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
            "date": date_str,
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
