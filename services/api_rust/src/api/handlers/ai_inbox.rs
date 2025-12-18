use axum::{extract::State, Json};
use chrono::Utc;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::{api::middleware::AuthUser, error::AppResult, AppState};

#[derive(Debug, Serialize, Deserialize)]
pub struct AiInboxMessage {
    pub id: String,
    pub content: String,
    pub kind: String,
    pub meal_type: String,
    pub date: String,
    pub created_at: String,
}

/// GET /v1/ai/inbox - get unread bot messages (and mark them as consumed)
pub async fn get_ai_inbox(
    State(state): State<AppState>,
    user: AuthUser,
) -> AppResult<Json<Vec<AiInboxMessage>>> {
    let query = format!(
        "user_id=eq.{}&consumed_at=is.null&select=id,content,kind,meal_type,date,created_at&order=created_at.asc&limit=20",
        user.user_id
    );

    let messages: Vec<AiInboxMessage> = state
        .supabase
        .select("ai_inbox_messages", &query, &user.token)
        .await?;

    // Mark as consumed to avoid showing duplicates in the app.
    if !messages.is_empty() {
        // Validate all IDs are valid UUIDs to prevent injection
        let validated_ids: Vec<String> = messages
            .iter()
            .filter_map(|m| Uuid::parse_str(&m.id).ok())
            .map(|id| id.to_string())
            .collect();

        if validated_ids.is_empty() {
            return Ok(Json(messages));
        }

        let update_query = format!("id=in.({})", validated_ids.join(","));

        let update_data = serde_json::json!({
            "consumed_at": Utc::now().to_rfc3339(),
        });

        state
            .supabase
            .update("ai_inbox_messages", &update_query, &update_data, &user.token)
            .await?;
    }

    Ok(Json(messages))
}


