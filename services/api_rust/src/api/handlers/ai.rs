use axum::{extract::State, Json};
use chrono::Utc;
use serde::{Deserialize, Serialize};

use crate::{
    api::middleware::AuthUser,
    error::{AppError, AppResult},
    state::{check_safety_flags, get_system_instruction, StateGenerator},
    AppState,
};

// =============================================================================
// POST /v1/ai/ask - Ask AI coach a question
// =============================================================================

#[derive(Debug, Deserialize)]
pub struct AskRequest {
    pub message: String,
    pub session_id: Option<String>,
}

#[derive(Debug, Serialize)]
pub struct AskResponse {
    pub session_id: String,
    pub answer_text: String,
    pub recommendations: Vec<RecommendationResponse>,
    pub warnings: Vec<String>,
}

#[derive(Debug, Serialize)]
pub struct RecommendationResponse {
    pub id: String,
    pub kind: String,
    pub payload: serde_json::Value,
}

// Supabase insert/response types
#[derive(Debug, Serialize)]
struct CreateAiSession {
    user_id: String,
    intent: String,
    model: String,
    input_summary: Option<serde_json::Value>,
    safety_flags: serde_json::Value,
}

#[derive(Debug, Deserialize)]
struct AiSessionResponse {
    id: String,
}

#[derive(Debug, Serialize)]
struct CreateAiMessage {
    session_id: String,
    role: String,
    content: String,
}

#[derive(Debug, Deserialize)]
struct AiMessageResponse {
    id: String,
}

#[derive(Debug, Serialize)]
struct CreateAiRecommendation {
    session_id: String,
    kind: String,
    payload: serde_json::Value,
}

#[derive(Debug, Deserialize)]
struct AiRecommendationResponse {
    id: String,
}

pub async fn ask_ai(
    State(state): State<AppState>,
    user: AuthUser,
    Json(req): Json<AskRequest>,
) -> AppResult<Json<AskResponse>> {
    // Check safety flags
    let safety_flags = check_safety_flags(&req.message);
    if safety_flags.iter().any(|f| f == "steroids" || f == "anabolics") {
        return Err(AppError::SafetyGuard(
            "This type of advice cannot be provided.".to_string(),
        ));
    }

    // Generate user state using Supabase REST API
    let today = Utc::now().date_naive();
    let state_gen = StateGenerator::new(&state.supabase, &user.token);
    let user_state = state_gen.generate(&user.user_id.clone(), today).await?;

    // Build prompt with state context
    let state_json = serde_json::to_string_pretty(&user_state)
        .map_err(|e| AppError::Internal(format!("Failed to serialize state: {}", e)))?;

    let prompt = format!(
        r#"【ユーザーの現在の状態】
```json
{}
```

【ユーザーの質問】
{}

上記の状態を踏まえて、適切なアドバイスをJSON形式で返してください。"#,
        state_json, req.message
    );

    // Get system instruction
    let system_instruction = get_system_instruction(&user_state);

    // Call Gemini
    let gemini_response = state.gemini.generate(&prompt, Some(&system_instruction)).await?;

    // Create AI session via Supabase REST API
    let session_data = CreateAiSession {
        user_id: user.user_id.clone(),
        intent: "ask".to_string(),
        model: state.config.gemini_model.clone(),
        input_summary: Some(serde_json::json!({
            "state_version": user_state.version,
            "goal": user_state.profile.goal,
            "today_workout_count": user_state.today.workout_count,
        })),
        safety_flags: serde_json::to_value(&safety_flags).unwrap(),
    };
    let session: AiSessionResponse = state
        .supabase
        .insert("ai_sessions", &session_data, &user.token)
        .await?;
    let session_id = session.id;

    // Save user message
    let user_message = CreateAiMessage {
        session_id: session_id.clone(),
        role: "user".to_string(),
        content: req.message.clone(),
    };
    let _: AiMessageResponse = state
        .supabase
        .insert("ai_messages", &user_message, &user.token)
        .await?;

    // Save AI response
    let ai_message = CreateAiMessage {
        session_id: session_id.clone(),
        role: "assistant".to_string(),
        content: gemini_response.answer_text.clone(),
    };
    let _: AiMessageResponse = state
        .supabase
        .insert("ai_messages", &ai_message, &user.token)
        .await?;

    // Save recommendations
    let mut recommendations = Vec::new();
    for rec in &gemini_response.recommendations {
        let rec_data = CreateAiRecommendation {
            session_id: session_id.clone(),
            kind: rec.kind.clone(),
            payload: rec.payload.clone(),
        };
        let rec_response: AiRecommendationResponse = state
            .supabase
            .insert("ai_recommendations", &rec_data, &user.token)
            .await?;
        recommendations.push(RecommendationResponse {
            id: rec_response.id,
            kind: rec.kind.clone(),
            payload: rec.payload.clone(),
        });
    }

    tracing::info!(
        user_id = %user.user_id,
        session_id = %session_id,
        "AI ask completed"
    );

    Ok(Json(AskResponse {
        session_id,
        answer_text: gemini_response.answer_text,
        recommendations,
        warnings: gemini_response.warnings,
    }))
}

// =============================================================================
// POST /v1/ai/plan/today - Generate today's workout plan
// =============================================================================

#[derive(Debug, Deserialize)]
pub struct PlanTodayRequest {
    pub muscle_groups: Option<Vec<String>>,
    pub duration_minutes: Option<i32>,
    pub equipment_available: Option<Vec<String>>,
}

#[derive(Debug, Serialize)]
pub struct PlanTodayResponse {
    pub session_id: String,
    pub plan: WorkoutPlan,
    pub answer_text: String,
    pub warnings: Vec<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct WorkoutPlan {
    pub title: String,
    pub estimated_duration_minutes: i32,
    pub exercises: Vec<PlannedExercise>,
    pub notes: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct PlannedExercise {
    pub name: String,
    pub muscle_tag: String,
    pub sets: i32,
    pub reps: String,
    pub rest_sec: i32,
    pub notes: Option<String>,
}

pub async fn plan_today(
    State(state): State<AppState>,
    user: AuthUser,
    Json(req): Json<PlanTodayRequest>,
) -> AppResult<Json<PlanTodayResponse>> {
    // Generate user state using Supabase REST API
    let today = Utc::now().date_naive();
    let state_gen = StateGenerator::new(&state.supabase, &user.token);
    let user_state = state_gen.generate(&user.user_id.clone(), today).await?;

    // Build prompt
    let state_json = serde_json::to_string_pretty(&user_state)
        .map_err(|e| AppError::Internal(format!("Failed to serialize state: {}", e)))?;

    let muscle_groups_str = req
        .muscle_groups
        .as_ref()
        .map(|m| m.join(", "))
        .unwrap_or_else(|| "おまかせ".to_string());

    let duration_str = req
        .duration_minutes
        .map(|d| format!("{}分", d))
        .unwrap_or_else(|| "60分程度".to_string());

    let equipment_str = req
        .equipment_available
        .as_ref()
        .map(|e| e.join(", "))
        .unwrap_or_else(|| "制限なし".to_string());

    let prompt = format!(
        r#"【ユーザーの現在の状態】
```json
{}
```

【今日のトレーニングプランをリクエスト】
- 鍛えたい部位: {}
- 希望時間: {}
- 利用可能な器具: {}

上記を踏まえて、今日のトレーニングプランを作成してください。

【出力形式】
{{
  "answer_text": "プランの説明",
  "recommendations": [
    {{
      "kind": "workout",
      "payload": {{
        "title": "プランのタイトル",
        "estimated_duration_minutes": 60,
        "exercises": [
          {{
            "name": "種目名",
            "muscle_tag": "chest",
            "sets": 3,
            "reps": "8-12",
            "rest_sec": 90,
            "notes": "フォームのポイントなど"
          }}
        ],
        "notes": "全体的な注意点"
      }}
    }}
  ],
  "warnings": []
}}"#,
        state_json, muscle_groups_str, duration_str, equipment_str
    );

    // Get system instruction
    let system_instruction = get_system_instruction(&user_state);

    // Call Gemini
    let gemini_response = state.gemini.generate(&prompt, Some(&system_instruction)).await?;

    // Extract workout plan from recommendations
    let plan = gemini_response
        .recommendations
        .iter()
        .find(|r| r.kind == "workout")
        .and_then(|r| serde_json::from_value::<WorkoutPlan>(r.payload.clone()).ok())
        .ok_or_else(|| {
            AppError::GeminiApi("Failed to parse workout plan from response".to_string())
        })?;

    // Create AI session via Supabase REST API
    let session_data = CreateAiSession {
        user_id: user.user_id.clone(),
        intent: "plan_today".to_string(),
        model: state.config.gemini_model.clone(),
        input_summary: Some(serde_json::json!({
            "muscle_groups": req.muscle_groups,
            "duration_minutes": req.duration_minutes,
        })),
        safety_flags: serde_json::json!([]),
    };
    let session: AiSessionResponse = state
        .supabase
        .insert("ai_sessions", &session_data, &user.token)
        .await?;
    let session_id = session.id;

    // Save AI response
    let ai_message = CreateAiMessage {
        session_id: session_id.clone(),
        role: "assistant".to_string(),
        content: gemini_response.answer_text.clone(),
    };
    let _: AiMessageResponse = state
        .supabase
        .insert("ai_messages", &ai_message, &user.token)
        .await?;

    // Save recommendation
    let rec_data = CreateAiRecommendation {
        session_id: session_id.clone(),
        kind: "workout".to_string(),
        payload: serde_json::to_value(&plan).unwrap(),
    };
    let _: AiRecommendationResponse = state
        .supabase
        .insert("ai_recommendations", &rec_data, &user.token)
        .await?;

    tracing::info!(
        user_id = %user.user_id,
        session_id = %session_id,
        "AI plan_today completed"
    );

    Ok(Json(PlanTodayResponse {
        session_id,
        plan,
        answer_text: gemini_response.answer_text,
        warnings: gemini_response.warnings,
    }))
}

// =============================================================================
// GET /v1/ai/history - Get AI conversation history
// =============================================================================

#[derive(Debug, Serialize)]
pub struct AiHistoryResponse {
    pub sessions: Vec<AiSessionSummary>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct AiSessionSummary {
    pub id: String,
    pub intent: String,
    pub created_at: String,
}

pub async fn get_ai_history(
    State(state): State<AppState>,
    user: AuthUser,
) -> AppResult<Json<AiHistoryResponse>> {
    let query = format!(
        "user_id=eq.{}&select=id,intent,created_at&order=created_at.desc&limit=50",
        user.user_id
    );
    let sessions: Vec<AiSessionSummary> = state
        .supabase
        .select("ai_sessions", &query, &user.token)
        .await?;

    Ok(Json(AiHistoryResponse { sessions }))
}
