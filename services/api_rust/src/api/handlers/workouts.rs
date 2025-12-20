use axum::{
    extract::{Path, Query, State},
    Extension, Json,
};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{
    api::middleware::AuthUser,
    api::validation::{validate_date_ymd, validate_uuid},
    error::AppResult,
    AppState,
};

// =============================================================================
// Request/Response DTOs
// =============================================================================

#[derive(Debug, Deserialize)]
pub struct ExercisesQuery {
    pub muscle_group: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct WorkoutsQuery {
    pub limit: Option<i32>,
    pub offset: Option<i32>,
}

#[derive(Debug, Serialize)]
pub struct ExerciseResponse {
    pub id: String,
    pub name: String,
    pub name_en: Option<String>,
    pub primary_muscle: String,
    pub secondary_muscles: Vec<String>,
    pub equipment: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct CreateExerciseRequest {
    pub name: String,
    pub primary_muscle: String,
    pub equipment: Option<String>,
    pub secondary_muscles: Option<Vec<String>>,
}

#[derive(Debug, Serialize)]
pub struct ExerciseWithStats {
    pub id: String,
    pub name: String,
    pub muscle_group: String,
    pub e1rm: f64,
    pub last_weight: f64,
    pub last_reps: i32,
    pub trend: f64,
}

#[derive(Debug, Serialize)]
pub struct WorkoutListItem {
    pub id: String,
    pub date: String,
    pub name: String,
    pub exercise_count: i32,
    pub duration_minutes: i32,
    pub total_volume: f64,
}

#[derive(Debug, Serialize)]
pub struct WorkoutDetail {
    pub id: String,
    pub date: String,
    pub start_time: Option<String>,
    pub end_time: Option<String>,
    pub perceived_fatigue: Option<i32>,
    pub note: Option<String>,
    pub exercises: Vec<WorkoutExerciseDetail>,
}

#[derive(Debug, Serialize)]
pub struct WorkoutExerciseDetail {
    pub id: String,
    pub exercise_id: Option<String>,
    pub exercise_name: String,
    pub muscle_tag: String,
    pub sets: Vec<WorkoutSetDetail>,
}

#[derive(Debug, Serialize)]
pub struct WorkoutSetDetail {
    pub set_index: i32,
    pub weight_kg: Option<f64>,
    pub reps: Option<i32>,
    pub rpe: Option<f64>,
    pub is_warmup: bool,
    pub is_dropset: bool,
}

#[derive(Debug, Deserialize)]
pub struct LogWorkoutRequest {
    pub date: String,
    pub start_time: Option<String>,
    pub end_time: Option<String>,
    pub perceived_fatigue: Option<i32>,
    pub note: Option<String>,
    pub exercises: Vec<LogWorkoutExercise>,
}

#[derive(Debug, Deserialize)]
pub struct LogWorkoutExercise {
    pub exercise_id: Option<String>,
    pub custom_name: Option<String>,
    pub muscle_tag: String,
    pub sets: Vec<LogWorkoutSet>,
}

#[derive(Debug, Deserialize)]
pub struct LogWorkoutSet {
    pub weight_kg: Option<f64>,
    pub reps: Option<i32>,
    pub rpe: Option<f64>,
    pub rest_sec: Option<i32>,
    pub is_warmup: Option<bool>,
    pub is_dropset: Option<bool>,
}

#[derive(Debug, Serialize)]
pub struct LogWorkoutResponse {
    pub workout_id: String,
    pub message: String,
}

// =============================================================================
// Handlers
// =============================================================================

// Allowed muscle group values (prevents injection)
const ALLOWED_MUSCLE_GROUPS: &[&str] = &[
    "chest", "back", "shoulders", "biceps", "triceps", "forearms",
    "abs", "obliques", "quads", "hamstrings", "glutes", "calves",
    "traps", "lats", "lower_back", "hip_flexors", "adductors", "abductors",
];

/// GET /exercises - Get all exercises
pub async fn get_exercises(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Query(params): Query<ExercisesQuery>,
) -> AppResult<Json<Vec<ExerciseResponse>>> {
    let mut query = "select=id,name,name_en,primary_muscle,secondary_muscles,equipment".to_string();

    if let Some(muscle_group) = &params.muscle_group {
        // Validate muscle_group to prevent injection
        if ALLOWED_MUSCLE_GROUPS.contains(&muscle_group.as_str()) {
            query.push_str(&format!("&primary_muscle=eq.{}", muscle_group));
        }
        // Invalid values are silently ignored (returns all exercises)
    }
    
    query.push_str("&order=name");

    let exercises: Vec<serde_json::Value> = state
        .supabase
        .select("exercises", &query, &user.token)
        .await?;

    let result: Vec<ExerciseResponse> = exercises
        .into_iter()
        .map(|e| ExerciseResponse {
            id: e["id"].as_str().unwrap_or_default().to_string(),
            name: e["name"].as_str().unwrap_or_default().to_string(),
            name_en: e["name_en"].as_str().map(String::from),
            primary_muscle: e["primary_muscle"].as_str().unwrap_or_default().to_string(),
            secondary_muscles: e["secondary_muscles"]
                .as_array()
                .map(|arr| arr.iter().filter_map(|v| v.as_str().map(String::from)).collect())
                .unwrap_or_default(),
            equipment: e["equipment"].as_str().map(String::from),
        })
        .collect();

    Ok(Json(result))
}

/// GET /exercises/stats - Get exercises with user's performance data
pub async fn get_exercises_with_stats(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
) -> AppResult<Json<Vec<ExerciseWithStats>>> {
    // Get system exercises + user's custom exercises
    // NOTE: user-defined exercises are stored with created_by=user_id and is_system=false
    let exercises_query = format!(
        "select=id,name,primary_muscle&or=(is_system.eq.true,created_by.eq.{})&order=name",
        user.user_id
    );
    let exercises: Vec<serde_json::Value> = state
        .supabase
        .select("exercises", &exercises_query, &user.token)
        .await?;

    // Get user's recent workout data (last 30 days)
    let thirty_days_ago = chrono::Utc::now()
        .checked_sub_signed(chrono::Duration::days(30))
        .unwrap()
        .format("%Y-%m-%d")
        .to_string();

    let workouts_query = format!(
        "user_id=eq.{}&date=gte.{}&select=id,date,workout_exercises(exercise_id,workout_sets(weight_kg,reps))",
        user.user_id, thirty_days_ago
    );
    let workouts: Vec<serde_json::Value> = state
        .supabase
        .select("workouts", &workouts_query, &user.token)
        .await?;

    // Build a map of exercise_id -> stats
    let mut exercise_stats: std::collections::HashMap<String, (f64, f64, i32, f64)> = std::collections::HashMap::new();

    for workout in &workouts {
        if let Some(exercises_arr) = workout["workout_exercises"].as_array() {
            for exercise in exercises_arr {
                let exercise_id = exercise["exercise_id"].as_str().unwrap_or_default();
                if exercise_id.is_empty() {
                    continue;
                }

                if let Some(sets) = exercise["workout_sets"].as_array() {
                    for set in sets {
                        let weight = set["weight_kg"].as_f64().unwrap_or(0.0);
                        let reps = set["reps"].as_i64().unwrap_or(0) as i32;
                        
                        if weight > 0.0 && reps > 0 {
                            // Calculate e1RM using Epley formula
                            let e1rm = if reps == 1 {
                                weight
                            } else {
                                weight * (1.0 + reps as f64 / 30.0)
                            };

                            let entry = exercise_stats
                                .entry(exercise_id.to_string())
                                .or_insert((0.0, 0.0, 0, 0.0));

                            // Update if this is a better e1RM
                            if e1rm > entry.0 {
                                entry.0 = e1rm;  // best e1rm
                                entry.1 = weight; // last weight
                                entry.2 = reps;   // last reps
                            }
                        }
                    }
                }
            }
        }
    }

    // Calculate trend (compare to previous period - simplified)
    let result: Vec<ExerciseWithStats> = exercises
        .into_iter()
        .map(|e| {
            let exercise_id = e["id"].as_str().unwrap_or_default().to_string();
            let stats = exercise_stats.get(&exercise_id).cloned().unwrap_or((0.0, 0.0, 0, 0.0));

            ExerciseWithStats {
                id: exercise_id,
                name: e["name"].as_str().unwrap_or_default().to_string(),
                muscle_group: e["primary_muscle"].as_str().unwrap_or_default().to_string(),
                e1rm: (stats.0 * 10.0).round() / 10.0,  // Round to 1 decimal
                last_weight: stats.1,
                last_reps: stats.2,
                trend: stats.3,
            }
        })
        .collect();

    Ok(Json(result))
}

/// POST /exercises - Create a user-defined exercise
pub async fn create_exercise(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Json(req): Json<CreateExerciseRequest>,
) -> AppResult<Json<ExerciseResponse>> {
    let name = req.name.trim();
    if name.is_empty() {
        return Err(crate::error::AppError::Validation(
            "Exercise name cannot be empty".to_string(),
        ));
    }
    if name.len() > 80 {
        return Err(crate::error::AppError::Validation(
            "Exercise name is too long (max 80 chars)".to_string(),
        ));
    }

    // Validate primary muscle to prevent injection
    if !ALLOWED_MUSCLE_GROUPS.contains(&req.primary_muscle.as_str()) {
        return Err(crate::error::AppError::Validation(format!(
            "Invalid primary_muscle. Allowed: {:?}",
            ALLOWED_MUSCLE_GROUPS
        )));
    }

    // Validate equipment (optional)
    const ALLOWED_EQUIPMENT: &[&str] = &[
        "barbell",
        "dumbbell",
        "machine",
        "cable",
        "bodyweight",
        "kettlebell",
        "band",
    ];
    if let Some(eq) = req.equipment.as_deref() {
        if !eq.is_empty() && !ALLOWED_EQUIPMENT.contains(&eq) {
            return Err(crate::error::AppError::Validation(format!(
                "Invalid equipment. Allowed: {:?}",
                ALLOWED_EQUIPMENT
            )));
        }
    }

    // Secondary muscles (optional) must be in allowed list
    if let Some(sec) = req.secondary_muscles.as_ref() {
        if sec.len() > 8 {
            return Err(crate::error::AppError::Validation(
                "secondary_muscles is too long (max 8)".to_string(),
            ));
        }
        for m in sec {
            if !ALLOWED_MUSCLE_GROUPS.contains(&m.as_str()) {
                return Err(crate::error::AppError::Validation(format!(
                    "Invalid secondary_muscle: {}",
                    m
                )));
            }
        }
    }

    let exercise_data = serde_json::json!({
        "name": name,
        "primary_muscle": req.primary_muscle,
        "secondary_muscles": req.secondary_muscles.unwrap_or_default(),
        "equipment": req.equipment,
        "is_system": false,
        "created_by": user.user_id,
    });

    let created: serde_json::Value = state
        .supabase
        .insert("exercises", &exercise_data, &user.token)
        .await?;

    Ok(Json(ExerciseResponse {
        id: created["id"].as_str().unwrap_or_default().to_string(),
        name: created["name"].as_str().unwrap_or_default().to_string(),
        name_en: created["name_en"].as_str().map(String::from),
        primary_muscle: created["primary_muscle"].as_str().unwrap_or_default().to_string(),
        secondary_muscles: created["secondary_muscles"]
            .as_array()
            .map(|arr| arr.iter().filter_map(|v| v.as_str().map(String::from)).collect())
            .unwrap_or_default(),
        equipment: created["equipment"].as_str().map(String::from),
    }))
}

/// GET /workouts - Get workout history
pub async fn get_workouts(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Query(params): Query<WorkoutsQuery>,
) -> AppResult<Json<Vec<WorkoutListItem>>> {
    let limit = params.limit.unwrap_or(20);
    let offset = params.offset.unwrap_or(0);

    let query = format!(
        "user_id=eq.{}&select=id,date,start_time,end_time,note,workout_exercises(id,exercise_id,muscle_tag,exercises(name),workout_sets(weight_kg,reps))&order=date.desc&limit={}&offset={}",
        user.user_id, limit, offset
    );

    let workouts: Vec<serde_json::Value> = state
        .supabase
        .select("workouts", &query, &user.token)
        .await?;

    let result: Vec<WorkoutListItem> = workouts
        .into_iter()
        .map(|w| {
            let exercises = w["workout_exercises"].as_array();
            let exercise_count = exercises.map(|e| e.len()).unwrap_or(0) as i32;

            // Calculate total volume
            let total_volume = exercises
                .map(|ex_arr| {
                    ex_arr.iter().map(|ex| {
                        ex["workout_sets"]
                            .as_array()
                            .map(|sets| {
                                sets.iter()
                                    .map(|s| {
                                        let weight = s["weight_kg"].as_f64().unwrap_or(0.0);
                                        let reps = s["reps"].as_i64().unwrap_or(0) as f64;
                                        weight * reps
                                    })
                                    .sum::<f64>()
                            })
                            .unwrap_or(0.0)
                    }).sum::<f64>()
                })
                .unwrap_or(0.0);

            // Calculate duration
            let duration_minutes = {
                let start = w["start_time"].as_str();
                let end = w["end_time"].as_str();
                match (start, end) {
                    (Some(s), Some(e)) => {
                        if let (Ok(start_dt), Ok(end_dt)) = (
                            chrono::DateTime::parse_from_rfc3339(s),
                            chrono::DateTime::parse_from_rfc3339(e),
                        ) {
                            (end_dt - start_dt).num_minutes() as i32
                        } else {
                            0
                        }
                    }
                    _ => 0,
                }
            };

            // Generate workout name from muscle tags
            let name = exercises
                .and_then(|ex_arr| {
                    let tags: Vec<&str> = ex_arr
                        .iter()
                        .filter_map(|e| e["muscle_tag"].as_str())
                        .collect::<std::collections::HashSet<_>>()
                        .into_iter()
                        .take(3)
                        .collect();
                    if tags.is_empty() {
                        None
                    } else {
                        Some(tags.join("・"))
                    }
                })
                .unwrap_or_else(|| "ワークアウト".to_string());

            WorkoutListItem {
                id: w["id"].as_str().unwrap_or_default().to_string(),
                date: w["date"].as_str().unwrap_or_default().to_string(),
                name,
                exercise_count,
                duration_minutes,
                total_volume,
            }
        })
        .collect();

    Ok(Json(result))
}

/// GET /workouts/:id - Get workout details
pub async fn get_workout_detail(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Path(workout_id): Path<String>,
) -> AppResult<Json<WorkoutDetail>> {
    let query = format!(
        "id=eq.{}&user_id=eq.{}&select=id,date,start_time,end_time,perceived_fatigue,note,workout_exercises(id,exercise_id,custom_exercise_name,muscle_tag,exercises(name),workout_sets(set_index,weight_kg,reps,rpe,is_warmup,is_dropset))",
        workout_id, user.user_id
    );

    let workouts: Vec<serde_json::Value> = state
        .supabase
        .select("workouts", &query, &user.token)
        .await?;

    let workout = workouts.into_iter().next()
        .ok_or_else(|| crate::error::AppError::NotFound("Workout not found".to_string()))?;

    let exercises: Vec<WorkoutExerciseDetail> = workout["workout_exercises"]
        .as_array()
        .map(|ex_arr| {
            ex_arr
                .iter()
                .map(|e| {
                    let exercise_name = e["exercises"]["name"]
                        .as_str()
                        .or_else(|| e["custom_exercise_name"].as_str())
                        .unwrap_or("Unknown")
                        .to_string();

                    let sets: Vec<WorkoutSetDetail> = e["workout_sets"]
                        .as_array()
                        .map(|s_arr| {
                            s_arr
                                .iter()
                                .map(|s| WorkoutSetDetail {
                                    set_index: s["set_index"].as_i64().unwrap_or(1) as i32,
                                    weight_kg: s["weight_kg"].as_f64(),
                                    reps: s["reps"].as_i64().map(|v| v as i32),
                                    rpe: s["rpe"].as_f64(),
                                    is_warmup: s["is_warmup"].as_bool().unwrap_or(false),
                                    is_dropset: s["is_dropset"].as_bool().unwrap_or(false),
                                })
                                .collect()
                        })
                        .unwrap_or_default();

                    WorkoutExerciseDetail {
                        id: e["id"].as_str().unwrap_or_default().to_string(),
                        exercise_id: e["exercise_id"].as_str().map(String::from),
                        exercise_name,
                        muscle_tag: e["muscle_tag"].as_str().unwrap_or_default().to_string(),
                        sets,
                    }
                })
                .collect()
        })
        .unwrap_or_default();

    Ok(Json(WorkoutDetail {
        id: workout["id"].as_str().unwrap_or_default().to_string(),
        date: workout["date"].as_str().unwrap_or_default().to_string(),
        start_time: workout["start_time"].as_str().map(String::from),
        end_time: workout["end_time"].as_str().map(String::from),
        perceived_fatigue: workout["perceived_fatigue"].as_i64().map(|v| v as i32),
        note: workout["note"].as_str().map(String::from),
        exercises,
    }))
}

/// POST /log/workout - Log a workout session
pub async fn log_workout(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Json(req): Json<LogWorkoutRequest>,
) -> AppResult<Json<LogWorkoutResponse>> {
    // Validate date format (also prevents storing unexpected strings)
    let date_str = validate_date_ymd(&req.date)?.format("%Y-%m-%d").to_string();

    // Basic size limits to reduce abuse/accidental huge payloads
    if req.exercises.is_empty() {
        return Err(crate::error::AppError::Validation(
            "At least one exercise is required".to_string(),
        ));
    }
    if req.exercises.len() > 50 {
        return Err(crate::error::AppError::Validation(
            "Too many exercises (max 50)".to_string(),
        ));
    }
    if let Some(note) = &req.note {
        if note.len() > 5000 {
            return Err(crate::error::AppError::Validation(
                "note is too long (max 5000 chars)".to_string(),
            ));
        }
    }

    for (idx, ex) in req.exercises.iter().enumerate() {
        if ex.sets.is_empty() {
            return Err(crate::error::AppError::Validation(format!(
                "Exercise {} must have at least one set",
                idx + 1
            )));
        }
        if ex.sets.len() > 50 {
            return Err(crate::error::AppError::Validation(format!(
                "Exercise {} has too many sets (max 50)",
                idx + 1
            )));
        }
        // If exercise_id is provided, it must be a UUID
        if let Some(ex_id) = ex.exercise_id.as_deref().filter(|s| !s.is_empty()) {
            let _ = validate_uuid(ex_id)?;
        }
    }

    let workout_id = Uuid::new_v4().to_string();

    // Insert workout
    let workout_data = serde_json::json!({
        "id": workout_id,
        "user_id": user.user_id,
        "date": date_str,
        "start_time": req.start_time,
        "end_time": req.end_time,
        "perceived_fatigue": req.perceived_fatigue,
        "note": req.note
    });

    let _: serde_json::Value = state
        .supabase
        .insert("workouts", &workout_data, &user.token)
        .await?;

    // Collect all exercises and sets for batch insert
    let mut exercise_data_list: Vec<serde_json::Value> = Vec::new();
    let mut set_data_list: Vec<serde_json::Value> = Vec::new();

    for (order, exercise) in req.exercises.iter().enumerate() {
        let exercise_entry_id = Uuid::new_v4().to_string();

        // Convert empty string to None for exercise_id (must be valid UUID or null)
        let exercise_id: Option<&str> = exercise.exercise_id.as_ref()
            .filter(|id| !id.is_empty())
            .map(|id| id.as_str());

        let exercise_data = serde_json::json!({
            "id": exercise_entry_id,
            "workout_id": workout_id,
            "exercise_id": exercise_id,
            "custom_exercise_name": exercise.custom_name,
            "muscle_tag": exercise.muscle_tag,
            "exercise_order": order as i32
        });

        exercise_data_list.push(exercise_data);

        // Collect sets for this exercise
        for (set_idx, set) in exercise.sets.iter().enumerate() {
            let set_data = serde_json::json!({
                "id": Uuid::new_v4().to_string(),
                "workout_exercise_id": exercise_entry_id,
                "set_index": (set_idx + 1) as i32,
                "weight_kg": set.weight_kg,
                "reps": set.reps,
                "rpe": set.rpe,
                "rest_sec": set.rest_sec,
                "is_warmup": set.is_warmup.unwrap_or(false),
                "is_dropset": set.is_dropset.unwrap_or(false)
            });

            set_data_list.push(set_data);
        }
    }

    // Batch insert exercises (1 query instead of N)
    state
        .supabase
        .insert_batch("workout_exercises", &exercise_data_list, &user.token)
        .await?;

    // Batch insert sets (1 query instead of M)
    state
        .supabase
        .insert_batch("workout_sets", &set_data_list, &user.token)
        .await?;

    Ok(Json(LogWorkoutResponse {
        workout_id,
        message: "Workout logged successfully".to_string(),
    }))
}

