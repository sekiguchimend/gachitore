use axum::{
    extract::{Path, State},
    http::StatusCode,
    Extension, Json,
};
use serde::{Deserialize, Serialize};

use crate::{
    api::middleware::AuthUser,
    error::{AppError, AppResult},
    infrastructure::supabase::{UserSubscription, UserBlock},
    AppState,
};

// =============================================================================
// Request/Response Models
// =============================================================================

#[derive(Debug, Deserialize)]
pub struct VerifyPurchaseRequest {
    pub platform: String,        // 'android' or 'ios'
    pub product_id: String,       // e.g., 'gachitore_basic_monthly'
    pub purchase_token: String,   // Google Play purchase token
    pub order_id: Option<String>, // Google Play order ID
}

#[derive(Debug, Serialize)]
pub struct SubscriptionResponse {
    pub subscription: UserSubscription,
}

#[derive(Debug, Deserialize)]
pub struct UpdateSnsLinksRequest {
    pub sns_links: Vec<SnsLink>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SnsLink {
    #[serde(rename = "type")]
    pub link_type: String, // 'twitter', 'instagram', 'youtube', etc.
    pub url: String,
}

#[derive(Debug, Serialize)]
pub struct SnsLinksResponse {
    pub sns_links: Vec<SnsLink>,
}

#[derive(Debug, Deserialize)]
pub struct BlockUserRequest {
    pub blocked_user_id: String,
}

#[derive(Debug, Serialize)]
pub struct BlockedUsersResponse {
    pub blocked_users: Vec<String>,
}

// =============================================================================
// Handlers: Subscription Management
// =============================================================================

/// POST /api/subscriptions/verify
/// Verify and record a subscription purchase from Google Play or App Store
pub async fn verify_purchase(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Json(req): Json<VerifyPurchaseRequest>,
) -> AppResult<Json<SubscriptionResponse>> {
    // Validate platform
    if req.platform != "android" && req.platform != "ios" {
        return Err(AppError::BadRequest(
            "Invalid platform. Must be 'android' or 'ios'".to_string(),
        ));
    }

    // Validate product_id
    let subscription_tier = match req.product_id.as_str() {
        "gachitore_basic_monthly" => "basic",
        "gachitore_premium_monthly" => "premium",
        _ => {
            return Err(AppError::BadRequest(format!(
                "Invalid product_id: {}",
                req.product_id
            )))
        }
    };

    // TODO: Verify purchase with Google Play Billing API or App Store API
    // For now, we'll trust the client (insecure - implement proper verification in production)

    // Calculate expiration date (30 days from now)
    let starts_at = chrono::Utc::now();
    let expires_at = starts_at + chrono::Duration::days(30);

    // Check if subscription already exists
    let existing_query = format!("user_id=eq.{}", user.user_id);
    let existing_subs: Vec<UserSubscription> = state
        .supabase
        .select("user_subscriptions", &existing_query, &user.token)
        .await?;

    let subscription = if existing_subs.is_empty() {
        // Create new subscription
        let new_sub = serde_json::json!({
            "user_id": user.user_id,
            "subscription_tier": subscription_tier,
            "platform": req.platform,
            "product_id": req.product_id,
            "purchase_token": req.purchase_token,
            "order_id": req.order_id,
            "starts_at": starts_at.to_rfc3339(),
            "expires_at": expires_at.to_rfc3339(),
            "auto_renewing": true,
            "status": "active",
        });

        let created: Vec<UserSubscription> = state
            .supabase
            .insert("user_subscriptions", &new_sub, &user.token)
            .await?;

        created
            .into_iter()
            .next()
            .ok_or_else(|| AppError::Internal("Failed to create subscription".to_string()))?
    } else {
        // Update existing subscription
        let update_data = serde_json::json!({
            "subscription_tier": subscription_tier,
            "platform": req.platform,
            "product_id": req.product_id,
            "purchase_token": req.purchase_token,
            "order_id": req.order_id,
            "starts_at": starts_at.to_rfc3339(),
            "expires_at": expires_at.to_rfc3339(),
            "auto_renewing": true,
            "status": "active",
            "updated_at": chrono::Utc::now().to_rfc3339(),
        });

        state
            .supabase
            .update(
                "user_subscriptions",
                &existing_query,
                &update_data,
                &user.token,
            )
            .await?;

        // Re-fetch the updated subscription
        let updated: Vec<UserSubscription> = state
            .supabase
            .select("user_subscriptions", &existing_query, &user.token)
            .await?;

        updated
            .into_iter()
            .next()
            .ok_or_else(|| AppError::Internal("Failed to update subscription".to_string()))?
    };

    Ok(Json(SubscriptionResponse { subscription }))
}

/// GET /api/subscriptions/me
/// Get current user's subscription status
pub async fn get_my_subscription(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
) -> AppResult<Json<SubscriptionResponse>> {
    let query = format!("user_id=eq.{}", user.user_id);
    let subscriptions: Vec<UserSubscription> = state
        .supabase
        .select("user_subscriptions", &query, &user.token)
        .await?;

    let subscription = subscriptions.into_iter().next().ok_or_else(|| {
        // Return a default free subscription if none exists
        AppError::NotFound("No subscription found".to_string())
    })?;

    Ok(Json(SubscriptionResponse { subscription }))
}

/// DELETE /api/subscriptions/me
/// Cancel current user's subscription (sets auto_renewing to false)
pub async fn cancel_subscription(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
) -> AppResult<StatusCode> {
    let query = format!("user_id=eq.{}", user.user_id);

    let update_data = serde_json::json!({
        "auto_renewing": false,
        "status": "cancelled",
        "updated_at": chrono::Utc::now().to_rfc3339(),
    });

    state
        .supabase
        .update("user_subscriptions", &query, &update_data, &user.token)
        .await?;

    Ok(StatusCode::NO_CONTENT)
}

// =============================================================================
// Handlers: SNS Links (Basic/Premium Feature)
// =============================================================================

/// PUT /api/users/me/sns-links
/// Update user's SNS links (requires Basic or Premium subscription)
pub async fn update_sns_links(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Json(req): Json<UpdateSnsLinksRequest>,
) -> AppResult<Json<SnsLinksResponse>> {
    // Check subscription tier (Basic+ required) - uses centralized check
    crate::api::subscription_check::require_subscription(
        &state,
        &user.user_id,
        &user.token,
        crate::api::subscription_check::SubscriptionTier::Basic,
        "SNSリンク機能",
    )
    .await?;

    // Validate SNS links
    for link in &req.sns_links {
        if !link.url.starts_with("http://") && !link.url.starts_with("https://") {
            return Err(AppError::BadRequest(format!(
                "Invalid URL format: {}",
                link.url
            )));
        }
    }

    // Update user_profiles
    let query = format!("user_id=eq.{}", user.user_id);
    let update_data = serde_json::json!({
        "sns_links": req.sns_links,
    });

    state
        .supabase
        .update("user_profiles", &query, &update_data, &user.token)
        .await?;

    Ok(Json(SnsLinksResponse {
        sns_links: req.sns_links,
    }))
}

/// GET /api/users/:user_id/sns-links
/// Get a user's SNS links (requires Basic or Premium subscription to view)
pub async fn get_user_sns_links(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Path(target_user_id): Path<String>,
) -> AppResult<Json<SnsLinksResponse>> {
    // Validate UUID
    crate::api::validation::validate_uuid(&target_user_id)?;

    // Check viewer's subscription tier (Basic+ required) - uses centralized check
    crate::api::subscription_check::require_subscription(
        &state,
        &user.user_id,
        &user.token,
        crate::api::subscription_check::SubscriptionTier::Basic,
        "SNSリンク閲覧",
    )
    .await?;

    // Fetch target user's profile
    let query = format!("user_id=eq.{}", target_user_id);
    let profiles: Vec<serde_json::Value> = state
        .supabase
        .select("user_profiles", &query, &user.token)
        .await?;

    let profile = profiles
        .into_iter()
        .next()
        .ok_or_else(|| AppError::NotFound("User not found".to_string()))?;

    let sns_links: Vec<SnsLink> = profile
        .get("sns_links")
        .and_then(|v| serde_json::from_value(v.clone()).ok())
        .unwrap_or_default();

    Ok(Json(SnsLinksResponse { sns_links }))
}

// =============================================================================
// Handlers: User Blocking (Premium Feature)
// =============================================================================

/// POST /api/blocks
/// Block a user (requires Premium subscription)
pub async fn block_user(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Json(req): Json<BlockUserRequest>,
) -> AppResult<StatusCode> {
    // Validate UUID
    crate::api::validation::validate_uuid(&req.blocked_user_id)?;

    // Check subscription tier (Premium required) - uses centralized check
    crate::api::subscription_check::require_subscription(
        &state,
        &user.user_id,
        &user.token,
        crate::api::subscription_check::SubscriptionTier::Premium,
        "ユーザーブロック機能",
    )
    .await?;

    // Prevent blocking self
    if user.user_id == req.blocked_user_id {
        return Err(AppError::BadRequest(
            "Cannot block yourself".to_string(),
        ));
    }

    // Create block
    let block_data = serde_json::json!({
        "blocker_user_id": user.user_id,
        "blocked_user_id": req.blocked_user_id,
    });

    let _created: Vec<UserBlock> = state
        .supabase
        .insert("user_blocks", &block_data, &user.token)
        .await?;

    Ok(StatusCode::CREATED)
}

/// DELETE /api/blocks/:blocked_user_id
/// Unblock a user
pub async fn unblock_user(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Path(blocked_user_id): Path<String>,
) -> AppResult<StatusCode> {
    // Validate UUID
    crate::api::validation::validate_uuid(&blocked_user_id)?;

    let query = format!(
        "blocker_user_id=eq.{}&blocked_user_id=eq.{}",
        user.user_id, blocked_user_id
    );

    state
        .supabase
        .delete("user_blocks", &query, &user.token)
        .await?;

    Ok(StatusCode::NO_CONTENT)
}

/// GET /api/blocks
/// Get list of blocked users
pub async fn get_blocked_users(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
) -> AppResult<Json<BlockedUsersResponse>> {
    let query = format!("blocker_user_id=eq.{}", user.user_id);
    let blocks: Vec<UserBlock> = state
        .supabase
        .select("user_blocks", &query, &user.token)
        .await?;

    let blocked_users: Vec<String> = blocks
        .into_iter()
        .map(|b| b.blocked_user_id)
        .collect();

    Ok(Json(BlockedUsersResponse { blocked_users }))
}
