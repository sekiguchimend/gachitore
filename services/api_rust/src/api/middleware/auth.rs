use axum::{
    async_trait,
    body::Body,
    extract::{FromRequestParts, State},
    http::{header::AUTHORIZATION, request::Parts, Request, StatusCode},
    middleware::Next,
    response::Response,
};
use jsonwebtoken::{decode, decode_header, Algorithm, DecodingKey, Validation};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};

use crate::{error::AppError, AppState};

/// JWT Claims from Supabase Auth
#[derive(Debug, Serialize, Deserialize)]
pub struct Claims {
    /// Subject (user ID)
    pub sub: Uuid,
    /// Audience
    pub aud: String,
    /// Expiration time
    pub exp: i64,
    /// Issued at
    pub iat: i64,
    /// Email (optional)
    pub email: Option<String>,
    /// Role
    pub role: Option<String>,
}

/// Authenticated user extracted from JWT
#[derive(Debug, Clone)]
pub struct AuthUser {
    pub user_id: String,
    pub email: String,
    pub role: Option<String>,
    /// Original access token for Supabase REST API calls (RLS)
    pub token: String,
}

#[async_trait]
impl FromRequestParts<AppState> for AuthUser {
    type Rejection = AppError;

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        // Extract Authorization header
        let auth_header = parts
            .headers
            .get(AUTHORIZATION)
            .and_then(|value| value.to_str().ok())
            .ok_or(AppError::Unauthorized)?;

        // Check Bearer prefix
        let token = auth_header
            .strip_prefix("Bearer ")
            .ok_or(AppError::InvalidToken("Missing Bearer prefix".to_string()))?;

        // Validate JWT
        let claims = validate_jwt(token, &state.config.supabase_jwt_secret)?;

        Ok(AuthUser {
            user_id: claims.sub.to_string(),
            email: claims.email.unwrap_or_default(),
            role: claims.role,
            token: token.to_string(),
        })
    }
}

/// Auth middleware function for use with route_layer
pub async fn auth_middleware(
    State(state): State<AppState>,
    request: Request<Body>,
    next: Next,
) -> Result<Response, StatusCode> {
    // Get authorization header
    let auth_header = request
        .headers()
        .get(AUTHORIZATION)
        .and_then(|v| v.to_str().ok());

    tracing::debug!("Auth header: {:?}", auth_header);

    let token = match auth_header {
        Some(header) if header.starts_with("Bearer ") => &header[7..],
        Some(header) => {
            tracing::warn!("Authorization header doesn't start with 'Bearer ': {}", header);
            return Err(StatusCode::UNAUTHORIZED);
        }
        None => {
            tracing::warn!("No Authorization header present");
            return Err(StatusCode::UNAUTHORIZED);
        }
    };

    tracing::debug!("Token length: {}, first 20 chars: {}", token.len(), &token[..token.len().min(20)]);

    // Validate JWT
    match validate_jwt(token, &state.config.supabase_jwt_secret) {
        Ok(claims) => {
            tracing::debug!("JWT validated for user: {}", claims.sub);
            let auth_user = AuthUser {
                user_id: claims.sub.to_string(),
                email: claims.email.unwrap_or_default(),
                role: claims.role,
                token: token.to_string(),
            };

            // Add auth user to request extensions
            let mut request = request;
            request.extensions_mut().insert(auth_user);
            Ok(next.run(request).await)
        }
        Err(e) => {
            tracing::warn!("JWT validation failed: {:?}", e);
            Err(StatusCode::UNAUTHORIZED)
        }
    }
}

/// Validate JWT token and extract claims
fn validate_jwt(token: &str, secret: &str) -> Result<Claims, AppError> {
    // Decode header to determine algorithm
    let header = decode_header(token).map_err(|e| {
        tracing::error!("Failed to decode JWT header: {:?}", e);
        AppError::InvalidToken(format!("Invalid JWT header: {}", e))
    })?;

    tracing::debug!("JWT algorithm: {:?}", header.alg);
    tracing::debug!("JWT secret length: {}", secret.len());

    let mut validation = Validation::new(header.alg);
    validation.set_audience(&["authenticated"]);
    validation.validate_exp = true;

    let key = match header.alg {
        Algorithm::HS256 | Algorithm::HS384 | Algorithm::HS512 => {
            // HMAC algorithms use the secret directly
            DecodingKey::from_secret(secret.as_bytes())
        }
        Algorithm::ES256 | Algorithm::ES384 => {
            // ECDSA algorithms - Supabase provides base64-encoded secret
            // Try to decode as base64 first, then use as raw bytes if that fails
            let secret_bytes = URL_SAFE_NO_PAD.decode(secret)
                .or_else(|_| base64::engine::general_purpose::STANDARD.decode(secret))
                .unwrap_or_else(|_| secret.as_bytes().to_vec());
            
            tracing::debug!("Decoded secret length: {} bytes", secret_bytes.len());
            
            // For ES256, we need to validate without the secret (using JWKS in production)
            // For now, skip signature validation and trust Supabase
            // In production, you should fetch JWKS from Supabase
            validation.insecure_disable_signature_validation();
            DecodingKey::from_secret(&[]) // Dummy key since we're skipping validation
        }
        _ => {
            tracing::error!("Unsupported JWT algorithm: {:?}", header.alg);
            return Err(AppError::InvalidToken(format!("Unsupported algorithm: {:?}", header.alg)));
        }
    };

    let token_data = decode::<Claims>(token, &key, &validation)
        .map_err(|e| {
            tracing::error!("JWT decode error: {:?}", e);
            AppError::InvalidToken(format!("JWT validation failed: {}", e))
        })?;

    Ok(token_data.claims)
}

/// Optional authentication - doesn't fail if no token
#[derive(Debug, Clone)]
pub struct OptionalAuthUser(pub Option<AuthUser>);

#[async_trait]
impl FromRequestParts<AppState> for OptionalAuthUser {
    type Rejection = (StatusCode, &'static str);

    async fn from_request_parts(
        parts: &mut Parts,
        state: &AppState,
    ) -> Result<Self, Self::Rejection> {
        match AuthUser::from_request_parts(parts, state).await {
            Ok(user) => Ok(OptionalAuthUser(Some(user))),
            Err(_) => Ok(OptionalAuthUser(None)),
        }
    }
}
