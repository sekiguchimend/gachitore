use axum::{extract::State, http::StatusCode, Json};
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
struct SupabaseError {
    error: Option<String>,
    error_description: Option<String>,
    msg: Option<String>,
}

// =============================================================================
// Handlers
// =============================================================================

/// POST /auth/signup
pub async fn signup(
    State(state): State<AppState>,
    Json(req): Json<SignUpRequest>,
) -> AppResult<Json<AuthResponse>> {
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

    if !response.status().is_success() {
        let error: SupabaseError = response.json().await.unwrap_or(SupabaseError {
            error: Some("Unknown error".to_string()),
            error_description: None,
            msg: None,
        });
        return Err(crate::error::AppError::AuthError(
            error.error_description
                .or(error.msg)
                .or(error.error)
                .unwrap_or("Signup failed".to_string())
        ));
    }

    // Get raw response for debugging
    let response_text = response.text().await?;
    tracing::debug!("Supabase signup response: {}", response_text);

    // Parse the response
    let auth_response: SupabaseAuthResponse = serde_json::from_str(&response_text)
        .map_err(|e| {
            tracing::error!("Failed to parse signup response: {} - Body: {}", e, response_text);
            crate::error::AppError::AuthError(format!("Invalid signup response: {}", e))
        })?;

    // Check if tokens are present (email confirmation might be required)
    if auth_response.access_token.is_empty() {
        tracing::warn!("Signup succeeded but no access token returned (email confirmation may be required)");
        return Err(crate::error::AppError::AuthError(
            "メール確認が必要です。メールを確認してください。".to_string()
        ));
    }

    tracing::info!(
        "Signup successful - returning token (length: {}) for user: {}",
        auth_response.access_token.len(),
        auth_response.user.id
    );

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
        return Err(crate::error::AppError::AuthError(
            error.error_description
                .or(error.msg)
                .or(error.error)
                .unwrap_or("Invalid login credentials".to_string())
        ));
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
        return Err(crate::error::AppError::AuthError(
            error.error_description
                .or(error.msg)
                .or(error.error)
                .unwrap_or("Token refresh failed".to_string())
        ));
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
        return Err(crate::error::AppError::AuthError(
            error.error_description
                .or(error.msg)
                .or(error.error)
                .unwrap_or("Password reset failed".to_string())
        ));
    }

    Ok(Json(MessageResponse {
        message: "Password reset email sent".to_string(),
    }))
}
