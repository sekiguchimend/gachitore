use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use serde::Serialize;
use thiserror::Error;

/// Mask sensitive data in error messages for logging
/// Removes tokens, passwords, and other sensitive information
fn mask_sensitive_data(msg: &str) -> String {
    let mut masked = msg.to_string();

    // Mask JWT tokens (eyJ... pattern)
    let jwt_regex = regex::Regex::new(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+").ok();
    if let Some(re) = jwt_regex {
        masked = re.replace_all(&masked, "[MASKED_TOKEN]").to_string();
    }

    // Mask Bearer tokens
    let bearer_regex = regex::Regex::new(r"Bearer\s+[A-Za-z0-9_.-]+").ok();
    if let Some(re) = bearer_regex {
        masked = re.replace_all(&masked, "Bearer [MASKED]").to_string();
    }

    // Mask signed URL tokens
    let token_regex = regex::Regex::new(r"token=[A-Za-z0-9%_.-]+").ok();
    if let Some(re) = token_regex {
        masked = re.replace_all(&masked, "token=[MASKED]").to_string();
    }

    // Mask API keys (common patterns)
    let apikey_regex = regex::Regex::new(r"(apikey|api_key|key)=[\w-]+").ok();
    if let Some(re) = apikey_regex {
        masked = re.replace_all(&masked, "$1=[MASKED]").to_string();
    }

    masked
}

/// Application error types
#[derive(Error, Debug)]
pub enum AppError {
    #[error("Authentication required")]
    Unauthorized,

    #[error("Invalid token: {0}")]
    InvalidToken(String),

    #[error("Forbidden: {0}")]
    Forbidden(String),

    #[error("Authentication error: {0}")]
    AuthError(String),

    #[error("Upstream auth service error: {0}")]
    UpstreamAuth(String),

    #[error("Not found: {0}")]
    NotFound(String),

    #[error("Bad request: {0}")]
    BadRequest(String),

    #[error("Validation error: {0}")]
    Validation(String),

    #[error("Supabase API error: {0}")]
    SupabaseError(String),

    #[error("Gemini API error: {0}")]
    GeminiApi(String),

    #[error("External API error: {0}")]
    ExternalApi(#[from] reqwest::Error),

    #[error("Internal server error: {0}")]
    Internal(String),

    #[error("Safety guard triggered: {0}")]
    SafetyGuard(String),
}

/// Error response body
#[derive(Serialize)]
pub struct ErrorResponse {
    pub error: String,
    pub message: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub details: Option<serde_json::Value>,
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        let (status, error_type, message) = match &self {
            AppError::Unauthorized => (StatusCode::UNAUTHORIZED, "unauthorized", self.to_string()),
            AppError::InvalidToken(msg) => {
                (StatusCode::UNAUTHORIZED, "invalid_token", msg.clone())
            }
            AppError::Forbidden(msg) => (StatusCode::FORBIDDEN, "forbidden", msg.clone()),
            AppError::AuthError(msg) => (StatusCode::UNAUTHORIZED, "auth_error", msg.clone()),
            AppError::UpstreamAuth(msg) => {
                tracing::error!("Upstream auth error: {}", mask_sensitive_data(msg));
                (
                    StatusCode::BAD_GATEWAY,
                    "upstream_auth_error",
                    "認証サービスでエラーが発生しました。しばらく待ってから再試行してください".to_string(),
                )
            }
            AppError::NotFound(msg) => (StatusCode::NOT_FOUND, "not_found", msg.clone()),
            AppError::BadRequest(msg) => (StatusCode::BAD_REQUEST, "bad_request", msg.clone()),
            AppError::Validation(msg) => {
                (StatusCode::UNPROCESSABLE_ENTITY, "validation_error", msg.clone())
            }
            AppError::SupabaseError(msg) => {
                // Mask sensitive data before logging
                tracing::error!("Supabase API error: {}", mask_sensitive_data(msg));
                (
                    StatusCode::BAD_GATEWAY,
                    "supabase_error",
                    "Database operation failed".to_string(),
                )
            }
            AppError::GeminiApi(msg) => {
                tracing::error!("Gemini API error: {}", mask_sensitive_data(msg));
                (
                    StatusCode::BAD_GATEWAY,
                    "gemini_error",
                    "AI service temporarily unavailable".to_string(),
                )
            }
            AppError::ExternalApi(e) => {
                tracing::error!("External API error: {}", mask_sensitive_data(&format!("{:?}", e)));
                (
                    StatusCode::BAD_GATEWAY,
                    "external_api_error",
                    "External service error".to_string(),
                )
            }
            AppError::Internal(msg) => {
                tracing::error!("Internal error: {}", mask_sensitive_data(msg));
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "internal_error",
                    "Internal server error".to_string(),
                )
            }
            AppError::SafetyGuard(msg) => (
                StatusCode::BAD_REQUEST,
                "safety_guard",
                format!("Safety check failed: {}", msg),
            ),
        };

        let body = ErrorResponse {
            error: error_type.to_string(),
            message,
            details: None,
        };

        (status, Json(body)).into_response()
    }
}

/// Result type alias for convenience
pub type AppResult<T> = Result<T, AppError>;
