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

    tracing::debug!("Token received (length: {})", token.len());

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

    let mut validation = Validation::new(header.alg);
    validation.set_audience(&["authenticated"]);
    validation.validate_exp = true;

    let key = match header.alg {
        Algorithm::HS256 | Algorithm::HS384 | Algorithm::HS512 => {
            // HMAC algorithms use the secret directly
            DecodingKey::from_secret(secret.as_bytes())
        }
        Algorithm::ES256 | Algorithm::ES384 => {
            // ECDSA algorithms require JWKS validation which is not implemented
            // Supabase typically uses HS256 with JWT secret
            // If you receive ES256/ES384 tokens, implement JWKS fetching from:
            // https://<your-project>.supabase.co/auth/v1/.well-known/jwks.json
            tracing::error!(
                "Unsupported JWT algorithm {:?}. Configure Supabase to use HS256 or implement JWKS validation.",
                header.alg
            );
            return Err(AppError::InvalidToken(
                "ES256/ES384 algorithms require JWKS validation. Please use HS256.".to_string()
            ));
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
