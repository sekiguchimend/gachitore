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
use std::time::{Duration, Instant};
use uuid::Uuid;

use crate::{error::AppError, AppState};

// =============================================================================
// JWKS (for ES256/RS256)
// =============================================================================

#[derive(Debug, Clone)]
pub struct CachedJwks {
    pub jwks: Jwks,
    pub fetched_at: Instant,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Jwks {
    pub keys: Vec<Jwk>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct Jwk {
    pub kid: Option<String>,
    pub kty: String,
    pub alg: Option<String>,
    pub crv: Option<String>,
    // EC
    pub x: Option<String>,
    pub y: Option<String>,
    // RSA
    pub n: Option<String>,
    pub e: Option<String>,
    // Optional fields we don't currently use:
    // use, key_ops, x5c, x5t, etc.
}

// JWKS cache TTL: 5 minutes (shorter for faster key rotation response)
const JWKS_TTL: Duration = Duration::from_secs(300);

async fn get_jwks(state: &AppState, force_refresh: bool) -> Result<Jwks, AppError> {
    // Fast path: fresh cache (unless force refresh requested)
    if !force_refresh {
        let guard = state.jwks_cache.read().await;
        if let Some(cached) = guard.as_ref() {
            if cached.fetched_at.elapsed() < JWKS_TTL {
                return Ok(cached.jwks.clone());
            }
        }
    }

    // Fetch JWKS
    let url = state.config.supabase_jwks_url.clone();
    tracing::debug!("Fetching Supabase JWKS: {} (force_refresh={})", url, force_refresh);

    let client = reqwest::Client::new();
    let jwks = client
        .get(&url)
        .send()
        .await
        .map_err(|e| AppError::InvalidToken(format!("Failed to fetch JWKS: {}", e)))?
        .json::<Jwks>()
        .await
        .map_err(|e| AppError::InvalidToken(format!("Failed to parse JWKS: {}", e)))?;

    // Update cache
    {
        let mut guard = state.jwks_cache.write().await;
        *guard = Some(CachedJwks {
            jwks: jwks.clone(),
            fetched_at: Instant::now(),
        });
    }

    Ok(jwks)
}

/// Invalidate JWKS cache (call when key verification fails)
async fn invalidate_jwks_cache(state: &AppState) {
    let mut guard = state.jwks_cache.write().await;
    *guard = None;
    tracing::info!("JWKS cache invalidated");
}

fn decoding_key_from_jwk(jwk: &Jwk, alg: Algorithm) -> Result<DecodingKey, AppError> {
    match alg {
        Algorithm::ES256 | Algorithm::ES384 => {
            if jwk.kty != "EC" {
                return Err(AppError::InvalidToken(format!(
                    "JWKS key type mismatch: expected EC, got {}",
                    jwk.kty
                )));
            }
            let x = jwk
                .x
                .as_deref()
                .ok_or_else(|| AppError::InvalidToken("JWKS EC key missing x".to_string()))?;
            let y = jwk
                .y
                .as_deref()
                .ok_or_else(|| AppError::InvalidToken("JWKS EC key missing y".to_string()))?;

            // jsonwebtoken expects base64url-encoded coordinates as provided by JWKS
            DecodingKey::from_ec_components(x, y).map_err(|e| {
                AppError::InvalidToken(format!("Invalid JWKS EC key components: {}", e))
            })
        }
        Algorithm::RS256 | Algorithm::RS384 | Algorithm::RS512 => {
            if jwk.kty != "RSA" {
                return Err(AppError::InvalidToken(format!(
                    "JWKS key type mismatch: expected RSA, got {}",
                    jwk.kty
                )));
            }
            let n = jwk
                .n
                .as_deref()
                .ok_or_else(|| AppError::InvalidToken("JWKS RSA key missing n".to_string()))?;
            let e = jwk
                .e
                .as_deref()
                .ok_or_else(|| AppError::InvalidToken("JWKS RSA key missing e".to_string()))?;
            DecodingKey::from_rsa_components(n, e).map_err(|e| {
                AppError::InvalidToken(format!("Invalid JWKS RSA key components: {}", e))
            })
        }
        _ => Err(AppError::InvalidToken(format!(
            "Unsupported algorithm for JWKS validation: {:?}",
            alg
        ))),
    }
}

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
        let claims = validate_jwt(token, state).await?;

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

    let token = match auth_header {
        Some(header) if header.starts_with("Bearer ") => &header[7..],
        Some(header) => {
            // Do not log the header value (it may contain credentials)
            tracing::warn!("Authorization header doesn't start with 'Bearer '");
            return Err(StatusCode::UNAUTHORIZED);
        }
        None => {
            tracing::warn!("No Authorization header present");
            return Err(StatusCode::UNAUTHORIZED);
        }
    };

    tracing::debug!("Bearer token received (length: {})", token.len());

    // Validate JWT
    match validate_jwt(token, &state).await {
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
async fn validate_jwt(token: &str, state: &AppState) -> Result<Claims, AppError> {
    // Decode header to determine algorithm
    let header = decode_header(token).map_err(|e| {
        tracing::error!("Failed to decode JWT header: {:?}", e);
        AppError::InvalidToken(format!("Invalid JWT header: {}", e))
    })?;

    tracing::debug!("JWT algorithm: {:?}", header.alg);

    let mut validation = Validation::new(header.alg);
    validation.set_audience(&["authenticated"]);
    // Supabase access tokens have iss like: https://<project-ref>.supabase.co/auth/v1
    let issuer = format!("{}/auth/v1", state.config.supabase_url.trim_end_matches('/'));
    validation.set_issuer(&[issuer]);
    validation.validate_exp = true;

    let key = match header.alg {
        Algorithm::HS256 | Algorithm::HS384 | Algorithm::HS512 => {
            // HMAC algorithms use the secret directly
            if state.config.supabase_jwt_secret.is_empty() {
                return Err(AppError::InvalidToken(
                    "HS* token received but SUPABASE_JWT_SECRET is not configured".to_string(),
                ));
            }
            DecodingKey::from_secret(state.config.supabase_jwt_secret.as_bytes())
        }
        Algorithm::ES256 | Algorithm::ES384 => {
            let kid = header.kid.clone().ok_or_else(|| {
                AppError::InvalidToken("ES* token missing kid in header".to_string())
            })?;
            // Try with cached JWKS first, then refresh if key not found
            let mut jwks = get_jwks(state, false).await?;
            let mut jwk = jwks
                .keys
                .iter()
                .find(|k| k.kid.as_deref() == Some(kid.as_str()));

            // If key not found in cache, force refresh JWKS (key rotation may have occurred)
            if jwk.is_none() {
                tracing::info!("Key kid={} not found in cached JWKS, refreshing...", kid);
                invalidate_jwks_cache(state).await;
                jwks = get_jwks(state, true).await?;
                jwk = jwks
                    .keys
                    .iter()
                    .find(|k| k.kid.as_deref() == Some(kid.as_str()));
            }

            let jwk = jwk.ok_or_else(|| {
                AppError::InvalidToken(format!("No matching JWKS key for kid={}", kid))
            })?;
            decoding_key_from_jwk(jwk, header.alg)?
        }
        Algorithm::RS256 | Algorithm::RS384 | Algorithm::RS512 => {
            let kid = header.kid.clone().ok_or_else(|| {
                AppError::InvalidToken("RS* token missing kid in header".to_string())
            })?;
            // Try with cached JWKS first, then refresh if key not found
            let mut jwks = get_jwks(state, false).await?;
            let mut jwk = jwks
                .keys
                .iter()
                .find(|k| k.kid.as_deref() == Some(kid.as_str()));

            // If key not found in cache, force refresh JWKS (key rotation may have occurred)
            if jwk.is_none() {
                tracing::info!("Key kid={} not found in cached JWKS, refreshing...", kid);
                invalidate_jwks_cache(state).await;
                jwks = get_jwks(state, true).await?;
                jwk = jwks
                    .keys
                    .iter()
                    .find(|k| k.kid.as_deref() == Some(kid.as_str()));
            }

            let jwk = jwk.ok_or_else(|| {
                AppError::InvalidToken(format!("No matching JWKS key for kid={}", kid))
            })?;
            decoding_key_from_jwk(jwk, header.alg)?
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
