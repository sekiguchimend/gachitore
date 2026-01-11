/// Subscription tier checking utilities
/// Centralized logic to prevent bypass vulnerabilities

use crate::{
    error::{AppError, AppResult},
    infrastructure::supabase::UserSubscription,
    AppState,
};

/// Subscription tier enum
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SubscriptionTier {
    Free,
    Basic,
    Premium,
}

impl SubscriptionTier {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Free => "free",
            Self::Basic => "basic",
            Self::Premium => "premium",
        }
    }

    pub fn from_str(s: &str) -> Self {
        match s {
            "basic" => Self::Basic,
            "premium" => Self::Premium,
            _ => Self::Free,
        }
    }

    /// Check if this tier meets the required tier
    /// Premium > Basic > Free
    pub fn meets_requirement(&self, required: SubscriptionTier) -> bool {
        match required {
            SubscriptionTier::Free => true,
            SubscriptionTier::Basic => matches!(self, SubscriptionTier::Basic | SubscriptionTier::Premium),
            SubscriptionTier::Premium => matches!(self, SubscriptionTier::Premium),
        }
    }
}

/// Get user's current subscription tier
/// Returns Free if no active subscription found
pub async fn get_user_tier(
    state: &AppState,
    user_id: &str,
    token: &str,
) -> AppResult<SubscriptionTier> {
    let query = format!("user_id=eq.{}&select=subscription_tier,status,expires_at", user_id);
    let subscriptions: Vec<serde_json::Value> = state
        .supabase
        .select("user_subscriptions", &query, token)
        .await
        .unwrap_or_default();

    if let Some(sub) = subscriptions.first() {
        let tier_str = sub["subscription_tier"].as_str().unwrap_or("free");
        let status = sub["status"].as_str().unwrap_or("expired");
        let expires_at = sub["expires_at"].as_str().unwrap_or("");

        // CRITICAL: Check both status AND expiration
        let is_active = status == "active";
        let is_not_expired = chrono::DateTime::parse_from_rfc3339(expires_at)
            .map(|exp| exp.with_timezone(&chrono::Utc) > chrono::Utc::now())
            .unwrap_or(false);

        if is_active && is_not_expired {
            return Ok(SubscriptionTier::from_str(tier_str));
        }
    }

    Ok(SubscriptionTier::Free)
}

/// Require a specific subscription tier
/// Returns Forbidden error if user doesn't meet requirement
pub async fn require_subscription(
    state: &AppState,
    user_id: &str,
    token: &str,
    required_tier: SubscriptionTier,
    feature_name: &str,
) -> AppResult<()> {
    let current_tier = get_user_tier(state, user_id, token).await?;

    if !current_tier.meets_requirement(required_tier) {
        let tier_name = match required_tier {
            SubscriptionTier::Basic => "ベーシックプラン",
            SubscriptionTier::Premium => "プレミアムプラン",
            SubscriptionTier::Free => return Ok(()),
        };

        return Err(AppError::Forbidden(format!(
            "{} を使用するには{} 以上が必要です",
            feature_name, tier_name
        )));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tier_requirements() {
        assert!(SubscriptionTier::Premium.meets_requirement(SubscriptionTier::Free));
        assert!(SubscriptionTier::Premium.meets_requirement(SubscriptionTier::Basic));
        assert!(SubscriptionTier::Premium.meets_requirement(SubscriptionTier::Premium));

        assert!(SubscriptionTier::Basic.meets_requirement(SubscriptionTier::Free));
        assert!(SubscriptionTier::Basic.meets_requirement(SubscriptionTier::Basic));
        assert!(!SubscriptionTier::Basic.meets_requirement(SubscriptionTier::Premium));

        assert!(SubscriptionTier::Free.meets_requirement(SubscriptionTier::Free));
        assert!(!SubscriptionTier::Free.meets_requirement(SubscriptionTier::Basic));
        assert!(!SubscriptionTier::Free.meets_requirement(SubscriptionTier::Premium));
    }
}
