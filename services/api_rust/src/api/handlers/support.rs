use axum::{
    extract::{rejection::JsonRejection, State},
    Extension, Json,
};
use serde::{Deserialize, Serialize};

use crate::{
    api::middleware::AuthUser,
    error::{AppError, AppResult},
    AppState,
};

#[derive(Debug, Deserialize)]
pub struct CreateSupportContactRequest {
    pub subject: String,
    pub message: String,
    pub platform: Option<String>,
    pub app_version: Option<String>,
    pub device_info: Option<serde_json::Value>,
}

#[derive(Debug, Serialize)]
pub struct CreateSupportContactResponse {
    pub id: String,
    pub message: String,
}

/// POST /support/contact
pub async fn create_support_contact(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    payload: Result<Json<CreateSupportContactRequest>, JsonRejection>,
) -> AppResult<Json<CreateSupportContactResponse>> {
    let Json(req) = payload.map_err(|e| {
        AppError::BadRequest(format!("Invalid JSON body: {}", e))
    })?;

    let subject = req.subject.trim();
    let message = req.message.trim();

    if subject.is_empty() || message.is_empty() {
        return Err(AppError::Validation("subject and message are required".to_string()));
    }
    if subject.len() > 120 {
        return Err(AppError::Validation("subject is too long (max 120 chars)".to_string()));
    }
    if message.len() > 4000 {
        return Err(AppError::Validation("message is too long (max 4000 chars)".to_string()));
    }

    let row = serde_json::json!({
        "user_id": user.user_id,
        "email": user.email,
        "subject": subject,
        "message": message,
        "platform": req.platform,
        "app_version": req.app_version,
        "device_info": req.device_info.unwrap_or_else(|| serde_json::json!({})),
    });

    let created: serde_json::Value = state
        .supabase
        .insert("support_contacts", &row, &user.token)
        .await?;

    Ok(Json(CreateSupportContactResponse {
        id: created["id"].as_str().unwrap_or_default().to_string(),
        message: "お問い合わせを受け付けました".to_string(),
    }))
}


