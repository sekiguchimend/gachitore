use axum::{extract::{rejection::JsonRejection, State}, Json};
use serde::{Deserialize, Serialize};

use crate::{error::AppResult, AppState};

// =============================================================================
// Request/Response DTOs
// =============================================================================

#[derive(Debug, Deserialize)]
pub struct SignUpRequest {
    pub email: String,
    pub password: String,
}

#[derive(Debug, Deserialize)]
pub struct SignInRequest {
    pub email: String,
    pub password: String,
}

#[derive(Debug, Serialize)]
pub struct AuthResponse {
    pub access_token: String,
    pub refresh_token: String,
    pub token_type: String,
    pub expires_in: i64,
    pub user: UserInfo,
}

#[derive(Debug, Serialize)]
pub struct UserInfo {
    pub id: String,
    pub email: String,
}

#[derive(Debug, Deserialize)]
pub struct RefreshTokenRequest {
    pub refresh_token: String,
}

#[derive(Debug, Deserialize)]
pub struct ResetPasswordRequest {
    pub email: String,
}

#[derive(Debug, Serialize)]
pub struct MessageResponse {
    pub message: String,
}

// =============================================================================
// Supabase Auth API responses
// =============================================================================

#[derive(Debug, Deserialize)]
struct SupabaseAuthResponse {
    #[serde(default)]
    access_token: String,
    #[serde(default)]
    refresh_token: String,
    #[serde(default)]
    token_type: String,
    #[serde(default)]
    expires_in: i64,
    user: SupabaseUser,
}

#[derive(Debug, Deserialize)]
struct SupabaseUser {
    id: String,
    email: Option<String>,
}

#[derive(Debug, Deserialize)]
struct SupabaseSession {
    #[serde(default)]
    access_token: String,
    #[serde(default)]
    refresh_token: String,
    #[serde(default)]
    token_type: String,
    #[serde(default)]
    expires_in: i64,
}

#[derive(Debug, Deserialize)]
struct SupabaseUserSessionResponse {
    user: SupabaseUser,
    session: Option<SupabaseSession>,
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
enum SupabaseSignUpResponse {
    Token(SupabaseAuthResponse),
    UserSession(SupabaseUserSessionResponse),
}

#[derive(Debug, Deserialize)]
struct SupabaseError {
    error: Option<String>,
    error_description: Option<String>,
    msg: Option<String>,
}

// =============================================================================
// Helper Functions
// =============================================================================

/// Translate Supabase auth errors to user-friendly Japanese messages
fn translate_auth_error(error: &str) -> String {
    let error_lower = error.to_lowercase();

    if error_lower.contains("password") && error_lower.contains("6") {
        return "パスワードは6文字以上で入力してください".to_string();
    }
    if error_lower.contains("password") && (error_lower.contains("weak") || error_lower.contains("short") || error_lower.contains("length")) {
        return "パスワードが短すぎます。8文字以上で入力してください".to_string();
    }
    if error_lower.contains("email") && (error_lower.contains("invalid") || error_lower.contains("format")) {
        return "有効なメールアドレスを入力してください".to_string();
    }
    if error_lower.contains("already registered") || error_lower.contains("already exists") {
        return "このメールアドレスは既に登録されています".to_string();
    }
    if error_lower.contains("invalid login") || error_lower.contains("invalid credentials") {
        return "メールアドレスまたはパスワードが正しくありません".to_string();
    }
    if error_lower.contains("email not confirmed") {
        return "メールアドレスの確認が完了していません。メールをご確認ください".to_string();
    }
    if error_lower.contains("rate limit") || error_lower.contains("too many") {
        return "リクエストが多すぎます。しばらく待ってから再試行してください".to_string();
    }
    if error_lower.contains("user not found") {
        return "ユーザーが見つかりません".to_string();
    }
    if error_lower.contains("token") && error_lower.contains("expired") {
        return "セッションの有効期限が切れました。再度ログインしてください".to_string();
    }

    // Default: return a generic message
    "認証エラーが発生しました。入力内容をご確認ください".to_string()
}

// =============================================================================
// Handlers
// =============================================================================

/// POST /auth/signup
pub async fn signup(
    State(state): State<AppState>,
    payload: Result<Json<SignUpRequest>, JsonRejection>,
) -> AppResult<Json<AuthResponse>> {
    let Json(req) = payload.map_err(|_| {
        crate::error::AppError::BadRequest("リクエスト形式が不正です（email/password を確認してください）".to_string())
    })?;

    // Marker log to correlate with 500s (safe: does not print password/token)
    tracing::debug!("auth.signup called (email_len={})", req.email.len());
    // Also emit to stderr in case tracing output is filtered by the runtime/log collector.
    eprintln!("[auth.signup] called (email_len={})", req.email.len());

    let url = format!("{}/auth/v1/signup", state.config.supabase_url);

    let client = reqwest::Client::new();
    let response = client
        .post(&url)
        .header("apikey", &state.config.supabase_anon_key)
        .header("Content-Type", "application/json")
        .json(&serde_json::json!({
            "email": req.email,
            "password": req.password
        }))
        .send()
        .await?;

    let status = response.status();
    let response_text = response.text().await?;
    // Do not log raw bodies here: it may include access/refresh tokens.

    if !status.is_success() {
        tracing::warn!(
            "auth.signup upstream non-2xx (status={} body_len={})",
            status.as_u16(),
            response_text.len()
        );
        eprintln!(
            "[auth.signup] upstream non-2xx (status={} body_len={})",
            status.as_u16(),
            response_text.len()
        );

        let parsed_error: Option<SupabaseError> = serde_json::from_str(&response_text).ok();
        let raw_error = parsed_error
            .and_then(|e| e.error_description.or(e.msg).or(e.error))
            .unwrap_or_else(|| format!("Signup failed (status={})", status.as_u16()));

        // Supabase 側 5xx はこちらでは直せないので 502 として返す
        if status.is_server_error() {
            eprintln!(
                "[auth.signup] upstream 5xx -> UpstreamAuth (status={} body_len={})",
                status.as_u16(),
                response_text.len()
            );
            return Err(crate::error::AppError::UpstreamAuth(format!(
                "signup upstream failed: status={} body_len={}",
                status.as_u16(),
                response_text.len()
            )));
        }

        // Convert common Supabase errors to user-friendly Japanese messages
        let user_message = translate_auth_error(&raw_error);
        return Err(crate::error::AppError::BadRequest(user_message));
    }

    // Parse the response (Supabase may return different shapes depending on settings)
    let parsed: SupabaseSignUpResponse = serde_json::from_str(&response_text).map_err(|e| {
        tracing::error!(
            "Failed to parse signup response: {} (body_len={})",
            e,
            response_text.len()
        );
        eprintln!(
            "[auth.signup] parse failed: {} (body_len={})",
            e,
            response_text.len()
        );
        crate::error::AppError::UpstreamAuth(format!(
            "invalid signup response: {} (body_len={})",
            e,
            response_text.len()
        ))
    })?;

    let (user, session) = match parsed {
        SupabaseSignUpResponse::Token(v) => {
            // Old shape: tokens at top-level
            let sess = SupabaseSession {
                access_token: v.access_token,
                refresh_token: v.refresh_token,
                token_type: v.token_type,
                expires_in: v.expires_in,
            };
            (v.user, Some(sess))
        }
        SupabaseSignUpResponse::UserSession(v) => (v.user, v.session),
    };

    let session = match session {
        Some(s) if !s.access_token.is_empty() => s,
        _ => {
            tracing::warn!(
                "Signup succeeded but no access token returned (email confirmation may be required)"
            );
            eprintln!("[auth.signup] no access token returned (email confirmation may be required)");
            return Err(crate::error::AppError::AuthError(
                "メール確認が必要です。メールを確認してください。".to_string(),
            ));
        }
    };

    tracing::info!(
        "Signup successful - returning token (length: {}) for user: {}",
        session.access_token.len(),
        user.id
    );

    Ok(Json(AuthResponse {
        access_token: session.access_token,
        refresh_token: session.refresh_token,
        token_type: session.token_type,
        expires_in: session.expires_in,
        user: UserInfo {
            id: user.id,
            email: user.email.unwrap_or_default(),
        },
    }))
}

/// POST /auth/signin
pub async fn signin(
    State(state): State<AppState>,
    Json(req): Json<SignInRequest>,
) -> AppResult<Json<AuthResponse>> {
    let url = format!("{}/auth/v1/token?grant_type=password", state.config.supabase_url);

    let client = reqwest::Client::new();
    let response = client
        .post(&url)
        .header("apikey", &state.config.supabase_anon_key)
        .header("Content-Type", "application/json")
        .json(&serde_json::json!({
            "email": req.email,
            "password": req.password
        }))
        .send()
        .await?;

    if !response.status().is_success() {
        let error: SupabaseError = response.json().await.unwrap_or(SupabaseError {
            error: Some("Unknown error".to_string()),
            error_description: None,
            msg: None,
        });
        let raw_error = error.error_description
            .or(error.msg)
            .or(error.error)
            .unwrap_or_else(|| "Invalid login credentials".to_string());

        let user_message = translate_auth_error(&raw_error);
        return Err(crate::error::AppError::AuthError(user_message));
    }

    let auth_response: SupabaseAuthResponse = response.json().await?;

    Ok(Json(AuthResponse {
        access_token: auth_response.access_token,
        refresh_token: auth_response.refresh_token,
        token_type: auth_response.token_type,
        expires_in: auth_response.expires_in,
        user: UserInfo {
            id: auth_response.user.id,
            email: auth_response.user.email.unwrap_or_default(),
        },
    }))
}

/// POST /auth/refresh
pub async fn refresh_token(
    State(state): State<AppState>,
    Json(req): Json<RefreshTokenRequest>,
) -> AppResult<Json<AuthResponse>> {
    let url = format!("{}/auth/v1/token?grant_type=refresh_token", state.config.supabase_url);

    let client = reqwest::Client::new();
    let response = client
        .post(&url)
        .header("apikey", &state.config.supabase_anon_key)
        .header("Content-Type", "application/json")
        .json(&serde_json::json!({
            "refresh_token": req.refresh_token
        }))
        .send()
        .await?;

    if !response.status().is_success() {
        let error: SupabaseError = response.json().await.unwrap_or(SupabaseError {
            error: Some("Unknown error".to_string()),
            error_description: None,
            msg: None,
        });
        let raw_error = error.error_description
            .or(error.msg)
            .or(error.error)
            .unwrap_or_else(|| "Token refresh failed".to_string());

        let user_message = translate_auth_error(&raw_error);
        return Err(crate::error::AppError::AuthError(user_message));
    }

    let auth_response: SupabaseAuthResponse = response.json().await?;

    Ok(Json(AuthResponse {
        access_token: auth_response.access_token,
        refresh_token: auth_response.refresh_token,
        token_type: auth_response.token_type,
        expires_in: auth_response.expires_in,
        user: UserInfo {
            id: auth_response.user.id,
            email: auth_response.user.email.unwrap_or_default(),
        },
    }))
}

/// POST /auth/signout
pub async fn signout(
    State(state): State<AppState>,
    headers: axum::http::HeaderMap,
) -> AppResult<Json<MessageResponse>> {
    let token = headers
        .get("Authorization")
        .and_then(|v| v.to_str().ok())
        .and_then(|v| v.strip_prefix("Bearer "))
        .unwrap_or("");

    let url = format!("{}/auth/v1/logout", state.config.supabase_url);

    let client = reqwest::Client::new();
    let _ = client
        .post(&url)
        .header("apikey", &state.config.supabase_anon_key)
        .header("Authorization", format!("Bearer {}", token))
        .send()
        .await;

    Ok(Json(MessageResponse {
        message: "Successfully signed out".to_string(),
    }))
}

/// POST /auth/password/reset
pub async fn reset_password(
    State(state): State<AppState>,
    Json(req): Json<ResetPasswordRequest>,
) -> AppResult<Json<MessageResponse>> {
    let url = format!("{}/auth/v1/recover", state.config.supabase_url);

    let client = reqwest::Client::new();
    let response = client
        .post(&url)
        .header("apikey", &state.config.supabase_anon_key)
        .header("Content-Type", "application/json")
        .json(&serde_json::json!({
            "email": req.email
        }))
        .send()
        .await?;

    if !response.status().is_success() {
        let error: SupabaseError = response.json().await.unwrap_or(SupabaseError {
            error: Some("Unknown error".to_string()),
            error_description: None,
            msg: None,
        });
        let raw_error = error.error_description
            .or(error.msg)
            .or(error.error)
            .unwrap_or_else(|| "Password reset failed".to_string());

        let user_message = translate_auth_error(&raw_error);
        return Err(crate::error::AppError::AuthError(user_message));
    }

    Ok(Json(MessageResponse {
        message: "パスワードリセットメールを送信しました".to_string(),
    }))
}
