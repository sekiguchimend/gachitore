use axum::{extract::State, Extension, Json};
use chrono::Utc;
use serde::{Deserialize, Serialize};

use crate::{
    api::middleware::AuthUser,
    error::{AppError, AppResult},
    AppState,
};

#[derive(Debug, Deserialize)]
pub struct UpsertPushTokenRequest {
    pub token: String,
    pub platform: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct DeletePushTokenRequest {
    pub token: String,
}

#[derive(Debug, Serialize)]
pub struct PushTokenResponse {
    pub ok: bool,
}

/// POST /users/push-token
/// Save (or refresh) an FCM device token for the current user.
pub async fn upsert_push_token(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Json(req): Json<UpsertPushTokenRequest>,
) -> AppResult<Json<PushTokenResponse>> {
    let token = req.token.trim();
    if token.is_empty() {
        return Err(AppError::BadRequest("token is required".to_string()));
    }
    if token.len() > 4096 {
        return Err(AppError::BadRequest("token is too long".to_string()));
    }

    let now = Utc::now().to_rfc3339();
    let row = serde_json::json!({
        "user_id": user.user_id,
        "token": token,
        "platform": req.platform,
        "updated_at": now,
    });

    // Idempotent upsert (unique: user_id + token)
    state
        .supabase
        .upsert("user_push_tokens", &row, "user_id,token", &user.token)
        .await?;

    Ok(Json(PushTokenResponse { ok: true }))
}

/// DELETE /users/push-token
/// Remove an FCM device token for the current user.
pub async fn delete_push_token(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Json(req): Json<DeletePushTokenRequest>,
) -> AppResult<Json<PushTokenResponse>> {
    let token = req.token.trim();
    if token.is_empty() {
        return Err(AppError::BadRequest("token is required".to_string()));
    }

    // Token is user-provided; always URL-encode when embedding into PostgREST filters
    let token_enc = urlencoding::encode(token);
    state
        .supabase
        .delete(
            "user_push_tokens",
            &format!("user_id=eq.{}&token=eq.{}", user.user_id, token_enc),
            &user.token,
        )
        .await?;

    Ok(Json(PushTokenResponse { ok: true }))
}


