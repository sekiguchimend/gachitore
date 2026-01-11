# サブスクリプション機能実装フロー

## 📋 目次

1. [プラン概要](#プラン概要)
2. [技術スタック](#技術スタック)
3. [実装フェーズ](#実装フェーズ)
4. [データベース設計](#データベース設計)
5. [バックエンド実装](#バックエンド実装)
6. [フロントエンド実装](#フロントエンド実装)
7. [テスト手順](#テスト手順)
8. [リリース手順](#リリース手順)

---

## プラン概要

### 無料プラン
- ✅ 基本機能（ワークアウト記録、食事記録、AI相談）
- ✅ 掲示板閲覧・投稿
- ❌ プロフィールにSNS URL表示不可
- ❌ 他ユーザーの食事メニュー閲覧不可
- ❌ ログイン状態確認不可
- ❌ ブロック機能不可

### ベーシックプラン（¥1,000/月）
- ✅ 無料プランのすべて
- ✅ **プロフィールにSNS URLリンク表示** (Instagram, X, YouTube など)
- ✅ **他ユーザーの1日の食事メニュー閲覧**
- ❌ ログイン状態確認不可
- ❌ ブロック機能不可

### プレミアムプラン（¥3,000/月）
- ✅ ベーシックプランのすべて
- ✅ **ログイン状態確認機能**（オンライン/オフライン表示）
- ✅ **ブロック機能**（特定ユーザーからの閲覧をブロック）
- ✅ **プレミアムバッジ表示**

---

## 技術スタック

### フロントエンド（Flutter）
- `in_app_purchase`: ^3.2.0 - Google Play / App Store IAP
- `flutter_riverpod`: ^2.6.1 - 状態管理
- `shared_preferences`: サブスクリプション状態のローカルキャッシュ

### バックエンド（Rust API）
- RevenueCat または Google Play Billing Library
- Supabase Functions - Webhook処理

### データベース（Supabase）
- PostgreSQL - サブスクリプション管理テーブル
- Row Level Security (RLS) - プラン別アクセス制御

---

## 実装フェーズ

### Phase 1: データベース設計と基盤構築 (2-3日)
- [ ] Supabaseにサブスクリプションテーブル作成
- [ ] RLSポリシー設定
- [ ] ユーザープロフィールにサブスクリプション情報追加

### Phase 2: Google Play Console設定 (1日)
- [ ] アプリ内課金の有効化
- [ ] サブスクリプション商品の作成
- [ ] テスターアカウント設定

### Phase 3: バックエンド実装 (3-4日)
- [ ] サブスクリプション状態検証API
- [ ] Webhook処理（購入・更新・キャンセル）
- [ ] プラン別機能制御ロジック

### Phase 4: フロントエンド実装 (5-7日)
- [ ] IAP購入フロー実装
- [ ] サブスクリプション管理画面
- [ ] プラン別UI表示制御
- [ ] 各機能の実装（SNS URL、食事閲覧、ログイン状態、ブロック）

### Phase 5: テストと調整 (3-4日)
- [ ] サンドボックステスト
- [ ] エラーハンドリング
- [ ] 復元機能テスト

### Phase 6: リリース (1-2日)
- [ ] 本番環境デプロイ
- [ ] ドキュメント作成
- [ ] モニタリング設定

**合計推定期間: 15-21日**

---

## データベース設計

### 1. `user_subscriptions` テーブル

```sql
-- サブスクリプション管理テーブル
CREATE TABLE user_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subscription_tier TEXT NOT NULL CHECK (subscription_tier IN ('free', 'basic', 'premium')),

    -- Google Play / App Store情報
    platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
    product_id TEXT NOT NULL, -- 'basic_monthly' or 'premium_monthly'
    purchase_token TEXT, -- Google Play購入トークン
    transaction_id TEXT, -- App Store トランザクションID

    -- 有効期間
    starts_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    auto_renewing BOOLEAN DEFAULT true,

    -- ステータス
    status TEXT NOT NULL CHECK (status IN ('active', 'cancelled', 'expired', 'pending')) DEFAULT 'active',

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id) -- 1ユーザー1サブスクリプション
);

-- インデックス
CREATE INDEX idx_user_subscriptions_user_id ON user_subscriptions(user_id);
CREATE INDEX idx_user_subscriptions_expires_at ON user_subscriptions(expires_at);
CREATE INDEX idx_user_subscriptions_status ON user_subscriptions(status);

-- RLS有効化
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;

-- ポリシー: 自分のサブスクリプション情報のみ閲覧可能
CREATE POLICY "Users can view own subscription"
    ON user_subscriptions FOR SELECT
    USING (auth.uid() = user_id);

-- ポリシー: バックエンドのみ更新可能（service_role）
CREATE POLICY "Service role can manage subscriptions"
    ON user_subscriptions FOR ALL
    USING (auth.role() = 'service_role');
```

### 2. `user_profiles` テーブルに追加カラム

```sql
-- 既存のuser_profilesテーブルに追加
ALTER TABLE user_profiles
ADD COLUMN sns_links JSONB DEFAULT '[]'::jsonb,
ADD COLUMN is_online BOOLEAN DEFAULT false,
ADD COLUMN last_seen_at TIMESTAMPTZ,
ADD COLUMN subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'basic', 'premium'));

-- sns_linksの構造例:
-- [
--   {"platform": "instagram", "url": "https://instagram.com/username"},
--   {"platform": "x", "url": "https://x.com/username"},
--   {"platform": "youtube", "url": "https://youtube.com/@username"}
-- ]

-- インデックス
CREATE INDEX idx_user_profiles_subscription_tier ON user_profiles(subscription_tier);
CREATE INDEX idx_user_profiles_is_online ON user_profiles(is_online);
```

### 3. `user_blocks` テーブル

```sql
-- ユーザーブロック管理テーブル
CREATE TABLE user_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    blocker_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    blocked_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(blocker_user_id, blocked_user_id),
    CHECK (blocker_user_id != blocked_user_id) -- 自分自身はブロック不可
);

-- インデックス
CREATE INDEX idx_user_blocks_blocker ON user_blocks(blocker_user_id);
CREATE INDEX idx_user_blocks_blocked ON user_blocks(blocked_user_id);

-- RLS有効化
ALTER TABLE user_blocks ENABLE ROW LEVEL SECURITY;

-- ポリシー: 自分がブロックしたユーザーのみ閲覧可能
CREATE POLICY "Users can view own blocks"
    ON user_blocks FOR SELECT
    USING (auth.uid() = blocker_user_id);

-- ポリシー: プレミアムユーザーのみ作成・削除可能
CREATE POLICY "Premium users can manage blocks"
    ON user_blocks FOR ALL
    USING (
        auth.uid() = blocker_user_id AND
        EXISTS (
            SELECT 1 FROM user_profiles
            WHERE user_id = auth.uid()
            AND subscription_tier = 'premium'
        )
    );
```

### 4. RLSポリシーの更新（投稿の閲覧制限）

```sql
-- 既存のpostsテーブルのSELECTポリシーを更新
-- ブロックされているユーザーは投稿を見れない
DROP POLICY IF EXISTS "Posts are viewable by everyone" ON posts;

CREATE POLICY "Posts are viewable by non-blocked users"
    ON posts FOR SELECT
    USING (
        -- 自分の投稿は常に見える
        auth.uid() = user_id
        OR
        -- ブロックされていない投稿のみ見える
        NOT EXISTS (
            SELECT 1 FROM user_blocks
            WHERE blocker_user_id = posts.user_id
            AND blocked_user_id = auth.uid()
        )
    );
```

### 5. 関数: サブスクリプション状態取得

```sql
-- ユーザーのサブスクリプションティアを取得する関数
CREATE OR REPLACE FUNCTION get_user_subscription_tier(target_user_id UUID)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    tier TEXT;
BEGIN
    SELECT subscription_tier INTO tier
    FROM user_profiles
    WHERE user_id = target_user_id;

    RETURN COALESCE(tier, 'free');
END;
$$;

-- 有効なサブスクリプションをチェックする関数
CREATE OR REPLACE FUNCTION has_active_subscription(target_user_id UUID, required_tier TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    current_tier TEXT;
BEGIN
    SELECT subscription_tier INTO current_tier
    FROM user_profiles
    WHERE user_id = target_user_id;

    -- ティアの優先順位: premium > basic > free
    IF required_tier = 'basic' THEN
        RETURN current_tier IN ('basic', 'premium');
    ELSIF required_tier = 'premium' THEN
        RETURN current_tier = 'premium';
    ELSE
        RETURN true; -- free tier
    END IF;
END;
$$;
```

---

## バックエンド実装

### 1. Rust API エンドポイント

#### `services/api_rust/src/api/handlers/subscription.rs`

```rust
use axum::{Extension, Json};
use serde::{Deserialize, Serialize};
use crate::{AppState, error::{AppError, AppResult}, api::middleware::AuthUser};

// サブスクリプションティアの定義
#[derive(Debug, Serialize, Deserialize, Clone, PartialEq)]
#[serde(rename_all = "lowercase")]
pub enum SubscriptionTier {
    Free,
    Basic,
    Premium,
}

// サブスクリプション情報レスポンス
#[derive(Debug, Serialize)]
pub struct SubscriptionInfo {
    pub tier: SubscriptionTier,
    pub expires_at: Option<String>,
    pub auto_renewing: bool,
    pub status: String,
}

// GET /subscription/status - 自分のサブスクリプション情報を取得
pub async fn get_subscription_status(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
) -> AppResult<Json<SubscriptionInfo>> {
    crate::api::validation::validate_uuid(&user.user_id)?;

    let query = format!("user_id=eq.{}&select=*", user.user_id);
    let subscriptions: Vec<serde_json::Value> = state
        .supabase
        .select("user_subscriptions", &query, &user.token)
        .await?;

    if subscriptions.is_empty() {
        // サブスクリプションなし = 無料プラン
        return Ok(Json(SubscriptionInfo {
            tier: SubscriptionTier::Free,
            expires_at: None,
            auto_renewing: false,
            status: "free".to_string(),
        }));
    }

    let sub = &subscriptions[0];
    let tier_str = sub["subscription_tier"].as_str().unwrap_or("free");
    let tier = match tier_str {
        "basic" => SubscriptionTier::Basic,
        "premium" => SubscriptionTier::Premium,
        _ => SubscriptionTier::Free,
    };

    Ok(Json(SubscriptionInfo {
        tier,
        expires_at: sub["expires_at"].as_str().map(|s| s.to_string()),
        auto_renewing: sub["auto_renewing"].as_bool().unwrap_or(false),
        status: sub["status"].as_str().unwrap_or("unknown").to_string(),
    }))
}

// POST /subscription/verify - Google Play購入トークンの検証
#[derive(Debug, Deserialize)]
pub struct VerifyPurchaseRequest {
    pub product_id: String,      // "basic_monthly" or "premium_monthly"
    pub purchase_token: String,  // Google Play購入トークン
    pub platform: String,        // "android" or "ios"
}

pub async fn verify_purchase(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Json(req): Json<VerifyPurchaseRequest>,
) -> AppResult<Json<serde_json::Value>> {
    crate::api::validation::validate_uuid(&user.user_id)?;

    // TODO: Google Play Billing APIでトークン検証
    // - purchase_tokenをGoogle Play Developer APIで検証
    // - 有効期限、自動更新状態を取得
    // - user_subscriptionsテーブルに保存/更新

    // 仮実装（実際はGoogle APIを呼ぶ）
    let tier = if req.product_id.contains("premium") {
        "premium"
    } else if req.product_id.contains("basic") {
        "basic"
    } else {
        return Err(AppError::BadRequest("Invalid product_id".to_string()));
    };

    // サブスクリプション情報を保存
    let subscription_data = serde_json::json!({
        "user_id": user.user_id,
        "subscription_tier": tier,
        "platform": req.platform,
        "product_id": req.product_id,
        "purchase_token": req.purchase_token,
        "starts_at": chrono::Utc::now().to_rfc3339(),
        "expires_at": (chrono::Utc::now() + chrono::Duration::days(30)).to_rfc3339(),
        "auto_renewing": true,
        "status": "active",
    });

    // UPSERT (既存があれば更新、なければ挿入)
    state.supabase.upsert(
        "user_subscriptions",
        &subscription_data,
        "user_id",
        &user.token
    ).await?;

    // user_profilesのsubscription_tierも更新
    let profile_update = serde_json::json!({
        "subscription_tier": tier,
    });
    state.supabase.update(
        "user_profiles",
        &format!("user_id=eq.{}", user.user_id),
        &profile_update,
        &user.token
    ).await?;

    Ok(Json(serde_json::json!({
        "success": true,
        "tier": tier,
    })))
}

// POST /subscription/restore - 購入の復元
pub async fn restore_purchase(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
) -> AppResult<Json<SubscriptionInfo>> {
    crate::api::validation::validate_uuid(&user.user_id)?;

    // TODO: Google Play Billing APIで購入履歴を取得
    // - 最新の有効なサブスクリプションを取得
    // - user_subscriptionsに反映

    // 現状のサブスクリプション情報を返す
    get_subscription_status(State(state), Extension(user)).await
}
```

#### `services/api_rust/src/api/handlers/users.rs` に追加

```rust
// PATCH /users/profile/sns-links - SNSリンク更新（ベーシックプラン以上）
#[derive(Debug, Deserialize)]
pub struct UpdateSnsLinksRequest {
    pub sns_links: Vec<SnsLink>,
}

#[derive(Debug, Deserialize, Serialize)]
pub struct SnsLink {
    pub platform: String, // "instagram", "x", "youtube", etc.
    pub url: String,
}

pub async fn update_sns_links(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Json(req): Json<UpdateSnsLinksRequest>,
) -> AppResult<Json<MessageResponse>> {
    crate::api::validation::validate_uuid(&user.user_id)?;

    // サブスクリプションティアをチェック
    let profile_query = format!("user_id=eq.{}&select=subscription_tier", user.user_id);
    let profiles: Vec<serde_json::Value> = state
        .supabase
        .select("user_profiles", &profile_query, &user.token)
        .await?;

    if profiles.is_empty() {
        return Err(AppError::NotFound);
    }

    let tier = profiles[0]["subscription_tier"].as_str().unwrap_or("free");
    if tier == "free" {
        return Err(AppError::BadRequest(
            "ベーシックプラン以上が必要です".to_string()
        ));
    }

    // URL検証
    for link in &req.sns_links {
        if !link.url.starts_with("http://") && !link.url.starts_with("https://") {
            return Err(AppError::Validation(
                format!("無効なURL: {}", link.url)
            ));
        }
        // 最大5個まで
        if req.sns_links.len() > 5 {
            return Err(AppError::Validation(
                "SNSリンクは最大5個までです".to_string()
            ));
        }
    }

    // 更新
    let update_data = serde_json::json!({
        "sns_links": req.sns_links,
    });

    state.supabase.update(
        "user_profiles",
        &format!("user_id=eq.{}", user.user_id),
        &update_data,
        &user.token
    ).await?;

    Ok(Json(MessageResponse {
        message: "SNSリンクを更新しました".to_string(),
    }))
}
```

#### `services/api_rust/src/api/handlers/blocks.rs` (新規作成)

```rust
use axum::{Extension, Json, extract::{Path, State}};
use serde::{Deserialize, Serialize};
use crate::{AppState, error::{AppError, AppResult}, api::middleware::AuthUser};

// POST /blocks - ユーザーをブロック（プレミアムのみ）
#[derive(Debug, Deserialize)]
pub struct BlockUserRequest {
    pub blocked_user_id: String,
}

#[derive(Debug, Serialize)]
pub struct BlockResponse {
    pub success: bool,
    pub message: String,
}

pub async fn block_user(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Json(req): Json<BlockUserRequest>,
) -> AppResult<Json<BlockResponse>> {
    crate::api::validation::validate_uuid(&user.user_id)?;
    crate::api::validation::validate_uuid(&req.blocked_user_id)?;

    // 自分自身はブロック不可
    if user.user_id == req.blocked_user_id {
        return Err(AppError::BadRequest("自分自身はブロックできません".to_string()));
    }

    // プレミアムプランチェック
    let profile_query = format!("user_id=eq.{}&select=subscription_tier", user.user_id);
    let profiles: Vec<serde_json::Value> = state
        .supabase
        .select("user_profiles", &profile_query, &user.token)
        .await?;

    if profiles.is_empty() {
        return Err(AppError::NotFound);
    }

    let tier = profiles[0]["subscription_tier"].as_str().unwrap_or("free");
    if tier != "premium" {
        return Err(AppError::BadRequest(
            "この機能はプレミアムプラン限定です".to_string()
        ));
    }

    // ブロック追加
    let block_data = serde_json::json!({
        "blocker_user_id": user.user_id,
        "blocked_user_id": req.blocked_user_id,
    });

    state.supabase.insert(
        "user_blocks",
        &block_data,
        &user.token
    ).await?;

    Ok(Json(BlockResponse {
        success: true,
        message: "ユーザーをブロックしました".to_string(),
    }))
}

// DELETE /blocks/:blocked_user_id - ブロック解除
pub async fn unblock_user(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
    Path(blocked_user_id): Path<String>,
) -> AppResult<Json<BlockResponse>> {
    crate::api::validation::validate_uuid(&user.user_id)?;
    crate::api::validation::validate_uuid(&blocked_user_id)?;

    let delete_query = format!(
        "blocker_user_id=eq.{}&blocked_user_id=eq.{}",
        user.user_id, blocked_user_id
    );

    state.supabase.delete("user_blocks", &delete_query, &user.token).await?;

    Ok(Json(BlockResponse {
        success: true,
        message: "ブロックを解除しました".to_string(),
    }))
}

// GET /blocks - 自分がブロックしたユーザー一覧
pub async fn list_blocked_users(
    State(state): State<AppState>,
    Extension(user): Extension<AuthUser>,
) -> AppResult<Json<Vec<serde_json::Value>>> {
    crate::api::validation::validate_uuid(&user.user_id)?;

    let query = format!(
        "blocker_user_id=eq.{}&select=blocked_user_id,created_at",
        user.user_id
    );

    let blocks = state.supabase.select("user_blocks", &query, &user.token).await?;

    Ok(Json(blocks))
}
```

### 2. ルーティング追加

#### `services/api_rust/src/api/routes/mod.rs`

```rust
// サブスクリプション関連ルート
fn subscription_routes(state: AppState) -> Router<AppState> {
    Router::new()
        .route("/status", get(handlers::get_subscription_status))
        .route("/verify", post(handlers::verify_purchase))
        .route("/restore", post(handlers::restore_purchase))
        .route_layer(middleware::from_fn_with_state(state, auth_middleware))
}

// ブロック関連ルート
fn blocks_routes(state: AppState) -> Router<AppState> {
    Router::new()
        .route("/", get(handlers::list_blocked_users).post(handlers::block_user))
        .route("/:blocked_user_id", delete(handlers::unblock_user))
        .route_layer(middleware::from_fn_with_state(state, auth_middleware))
}

// メインルーターに追加
pub fn create_routes(state: AppState) -> Router<AppState> {
    Router::new()
        // ... 既存のルート
        .nest("/subscription", subscription_routes(state.clone()))
        .nest("/blocks", blocks_routes(state.clone()))
}
```

---

## フロントエンド実装

### 1. 依存関係追加

#### `apps/mobile_flutter/pubspec.yaml`

```yaml
dependencies:
  # 既存の依存関係...

  # In-App Purchase
  in_app_purchase: ^3.2.0
  in_app_purchase_android: ^0.3.6+5
  in_app_purchase_storekit: ^0.3.17+3
```

### 2. モデル定義

#### `lib/data/models/subscription_models.dart`

```dart
enum SubscriptionTier {
  free,
  basic,
  premium;

  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return '無料';
      case SubscriptionTier.basic:
        return 'ベーシック';
      case SubscriptionTier.premium:
        return 'プレミアム';
    }
  }

  String get price {
    switch (this) {
      case SubscriptionTier.free:
        return '¥0';
      case SubscriptionTier.basic:
        return '¥1,000/月';
      case SubscriptionTier.premium:
        return '¥3,000/月';
    }
  }

  List<String> get features {
    switch (this) {
      case SubscriptionTier.free:
        return [
          '基本機能',
          'ワークアウト記録',
          '食事記録',
          'AI相談（制限あり）',
        ];
      case SubscriptionTier.basic:
        return [
          '無料プランのすべて',
          'プロフィールにSNS URL表示',
          '他ユーザーの食事メニュー閲覧',
        ];
      case SubscriptionTier.premium:
        return [
          'ベーシックプランのすべて',
          'ログイン状態確認',
          'ブロック機能',
          'プレミアムバッジ',
        ];
    }
  }

  String get productId {
    switch (this) {
      case SubscriptionTier.basic:
        return 'basic_monthly';
      case SubscriptionTier.premium:
        return 'premium_monthly';
      case SubscriptionTier.free:
        return '';
    }
  }
}

class SubscriptionInfo {
  final SubscriptionTier tier;
  final DateTime? expiresAt;
  final bool autoRenewing;
  final String status;

  const SubscriptionInfo({
    required this.tier,
    this.expiresAt,
    required this.autoRenewing,
    required this.status,
  });

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) {
    return SubscriptionInfo(
      tier: SubscriptionTier.values.firstWhere(
        (e) => e.name == json['tier'],
        orElse: () => SubscriptionTier.free,
      ),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      autoRenewing: json['auto_renewing'] ?? false,
      status: json['status'] ?? 'free',
    );
  }

  bool get isActive =>
      status == 'active' &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  bool hasFeature(String feature) {
    switch (feature) {
      case 'sns_links':
        return tier == SubscriptionTier.basic || tier == SubscriptionTier.premium;
      case 'view_meals':
        return tier == SubscriptionTier.basic || tier == SubscriptionTier.premium;
      case 'online_status':
        return tier == SubscriptionTier.premium;
      case 'block_users':
        return tier == SubscriptionTier.premium;
      default:
        return false;
    }
  }
}

class SnsLink {
  final String platform;
  final String url;

  const SnsLink({
    required this.platform,
    required this.url,
  });

  factory SnsLink.fromJson(Map<String, dynamic> json) {
    return SnsLink(
      platform: json['platform'],
      url: json['url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'url': url,
    };
  }

  String get iconAsset {
    switch (platform.toLowerCase()) {
      case 'instagram':
        return 'assets/icons/instagram.svg';
      case 'x':
      case 'twitter':
        return 'assets/icons/x.svg';
      case 'youtube':
        return 'assets/icons/youtube.svg';
      case 'tiktok':
        return 'assets/icons/tiktok.svg';
      default:
        return 'assets/icons/link.svg';
    }
  }
}
```

### 3. サービス層

#### `lib/data/services/subscription_service.dart`

```dart
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../models/subscription_models.dart';

class SubscriptionService {
  final Dio _dio;
  final InAppPurchase _iap = InAppPurchase.instance;

  // 商品ID
  static const String basicMonthlyId = 'basic_monthly';
  static const String premiumMonthlyId = 'premium_monthly';
  static const Set<String> _productIds = {basicMonthlyId, premiumMonthlyId};

  // 購入ストリーム
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  SubscriptionService(this._dio);

  /// 初期化
  Future<void> initialize() async {
    final available = await _iap.isAvailable();
    if (!available) {
      throw Exception('In-App Purchase not available');
    }

    // 購入リスナーを設定
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) => print('Purchase stream error: $error'),
    );
  }

  /// 購入イベント処理
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (var purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // サーバーで検証
        await _verifyPurchase(purchase);
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  /// サーバーで購入を検証
  Future<void> _verifyPurchase(PurchaseDetails purchase) async {
    try {
      String? purchaseToken;
      if (purchase is GooglePlayPurchaseDetails) {
        purchaseToken = purchase.billingClientPurchase.purchaseToken;
      }

      await _dio.post(
        '/subscription/verify',
        data: {
          'product_id': purchase.productID,
          'purchase_token': purchaseToken,
          'platform': 'android',
        },
      );
    } catch (e) {
      print('Purchase verification failed: $e');
      rethrow;
    }
  }

  /// 利用可能な商品を取得
  Future<List<ProductDetails>> getProducts() async {
    final response = await _iap.queryProductDetails(_productIds);

    if (response.error != null) {
      throw Exception('Failed to query products: ${response.error}');
    }

    return response.productDetails;
  }

  /// 購入開始
  Future<void> purchaseSubscription(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    await _iap.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// 購入の復元
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();

      // サーバー側でも復元
      await _dio.post('/subscription/restore');
    } catch (e) {
      print('Restore failed: $e');
      rethrow;
    }
  }

  /// サブスクリプション情報を取得
  Future<SubscriptionInfo> getSubscriptionInfo() async {
    try {
      final response = await _dio.get('/subscription/status');
      return SubscriptionInfo.fromJson(response.data);
    } catch (e) {
      print('Failed to get subscription info: $e');
      rethrow;
    }
  }

  /// クリーンアップ
  void dispose() {
    _subscription?.cancel();
  }
}
```

#### `lib/data/services/block_service.dart`

```dart
import 'package:dio/dio.dart';

class BlockService {
  final Dio _dio;

  BlockService(this._dio);

  /// ユーザーをブロック
  Future<void> blockUser(String userId) async {
    await _dio.post('/blocks', data: {'blocked_user_id': userId});
  }

  /// ブロック解除
  Future<void> unblockUser(String userId) async {
    await _dio.delete('/blocks/$userId');
  }

  /// ブロックしたユーザー一覧を取得
  Future<List<String>> getBlockedUsers() async {
    final response = await _dio.get('/blocks');
    return (response.data as List)
        .map((e) => e['blocked_user_id'] as String)
        .toList();
  }

  /// 特定のユーザーがブロックされているかチェック
  Future<bool> isUserBlocked(String userId) async {
    final blockedUsers = await getBlockedUsers();
    return blockedUsers.contains(userId);
  }
}
```

### 4. プロバイダー（Riverpod）

#### `lib/presentation/providers/subscription_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../data/models/subscription_models.dart';
import '../../data/services/subscription_service.dart';
import 'api_provider.dart';

// サブスクリプションサービスプロバイダー
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  final dio = ref.watch(dioProvider);
  return SubscriptionService(dio);
});

// サブスクリプション情報プロバイダー
final subscriptionInfoProvider = FutureProvider<SubscriptionInfo>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  return await service.getSubscriptionInfo();
});

// 利用可能な商品プロバイダー
final availableProductsProvider = FutureProvider<List<ProductDetails>>((ref) async {
  final service = ref.watch(subscriptionServiceProvider);
  await service.initialize();
  return await service.getProducts();
});

// 購入処理プロバイダー
final purchaseControllerProvider = StateNotifierProvider<PurchaseController, AsyncValue<void>>((ref) {
  final service = ref.watch(subscriptionServiceProvider);
  return PurchaseController(service);
});

class PurchaseController extends StateNotifier<AsyncValue<void>> {
  final SubscriptionService _service;

  PurchaseController(this._service) : super(const AsyncValue.data(null));

  Future<void> purchase(ProductDetails product) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.purchaseSubscription(product);
    });
  }

  Future<void> restore() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _service.restorePurchases();
    });
  }
}
```

### 5. UI実装

#### `lib/presentation/pages/subscription/subscription_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/subscription_provider.dart';
import '../../../data/models/subscription_models.dart';

class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(subscriptionInfoProvider);
    final productsAsync = ref.watch(availableProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('プラン変更'),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(purchaseControllerProvider.notifier).restore();
              ref.invalidate(subscriptionInfoProvider);
            },
            child: const Text('購入を復元'),
          ),
        ],
      ),
      body: subscriptionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('エラー: $error')),
        data: (currentSubscription) {
          return productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(child: Text('商品の読み込みに失敗: $error')),
            data: (products) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 現在のプラン表示
                  _CurrentPlanCard(subscription: currentSubscription),
                  const SizedBox(height: 24),

                  // プラン一覧
                  _PlanCard(
                    tier: SubscriptionTier.free,
                    isCurrent: currentSubscription.tier == SubscriptionTier.free,
                    onSelect: null, // 無料プランは選択不可
                  ),
                  const SizedBox(height: 16),
                  _PlanCard(
                    tier: SubscriptionTier.basic,
                    isCurrent: currentSubscription.tier == SubscriptionTier.basic,
                    product: products.firstWhere(
                      (p) => p.id == SubscriptionTier.basic.productId,
                      orElse: () => products.first,
                    ),
                    onSelect: (product) async {
                      await ref.read(purchaseControllerProvider.notifier).purchase(product);
                      ref.invalidate(subscriptionInfoProvider);
                    },
                  ),
                  const SizedBox(height: 16),
                  _PlanCard(
                    tier: SubscriptionTier.premium,
                    isCurrent: currentSubscription.tier == SubscriptionTier.premium,
                    product: products.firstWhere(
                      (p) => p.id == SubscriptionTier.premium.productId,
                      orElse: () => products.last,
                    ),
                    onSelect: (product) async {
                      await ref.read(purchaseControllerProvider.notifier).purchase(product);
                      ref.invalidate(subscriptionInfoProvider);
                    },
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  final SubscriptionInfo subscription;

  const _CurrentPlanCard({required this.subscription});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF323232),
      child: Padding(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '現在のプラン',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subscription.tier.displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          if (subscription.expiresAt != null) ...[
            const SizedBox(height: 8),
            Text(
              '有効期限: ${subscription.expiresAt!.toString().split(' ')[0]}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionTier tier;
  final bool isCurrent;
  final ProductDetails? product;
  final Function(ProductDetails)? onSelect;

  const _PlanCard({
    required this.tier,
    required this.isCurrent,
    this.product,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isCurrent ? const Color(0xFF323232) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier.displayName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isCurrent ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product?.price ?? tier.price,
                      style: TextStyle(
                        fontSize: 16,
                        color: isCurrent ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '現在のプラン',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF323232),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...tier.features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: isCurrent ? Colors.white : const Color(0xFF323232),
                ),
                const SizedBox(width: 8),
                Text(
                  feature,
                  style: TextStyle(
                    fontSize: 14,
                    color: isCurrent ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          )),
          if (!isCurrent && onSelect != null && product != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => onSelect!(product!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF323232),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('このプランにする'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

#### `lib/presentation/pages/settings/sns_links_edit_page.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/subscription_models.dart';

class SnsLinksEditPage extends ConsumerStatefulWidget {
  final List<SnsLink> initialLinks;

  const SnsLinksEditPage({
    super.key,
    required this.initialLinks,
  });

  @override
  ConsumerState<SnsLinksEditPage> createState() => _SnsLinksEditPageState();
}

class _SnsLinksEditPageState extends ConsumerState<SnsLinksEditPage> {
  late List<SnsLink> _links;
  final _formKey = GlobalKey<FormState>();

  static const _platforms = [
    'Instagram',
    'X (Twitter)',
    'YouTube',
    'TikTok',
    'その他',
  ];

  @override
  void initState() {
    super.initState();
    _links = List.from(widget.initialLinks);
  }

  void _addLink() {
    if (_links.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SNSリンクは最大5個までです')),
      );
      return;
    }

    setState(() {
      _links.add(const SnsLink(platform: 'Instagram', url: ''));
    });
  }

  void _removeLink(int index) {
    setState(() {
      _links.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      // TODO: API呼び出し
      // await ref.read(userServiceProvider).updateSnsLinks(_links);

      Navigator.of(context).pop(_links);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SNSリンク編集'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'プロフィールに表示するSNSリンクを追加できます（最大5個）',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            ..._links.asMap().entries.map((entry) {
              final index = entry.key;
              final link = entry.value;
              return _LinkEditCard(
                key: ValueKey(index),
                link: link,
                platforms: _platforms,
                onChanged: (newLink) {
                  setState(() {
                    _links[index] = newLink;
                  });
                },
                onRemove: () => _removeLink(index),
              );
            }),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _addLink,
              icon: const Icon(Icons.add),
              label: const Text('SNSリンクを追加'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white30),
              ),
            ),
          ],
        ),
      ),
      backgroundColor: Colors.black,
    );
  }
}

class _LinkEditCard extends StatefulWidget {
  final SnsLink link;
  final List<String> platforms;
  final Function(SnsLink) onChanged;
  final VoidCallback onRemove;

  const _LinkEditCard({
    super.key,
    required this.link,
    required this.platforms,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_LinkEditCard> createState() => _LinkEditCardState();
}

class _LinkEditCardState extends State<_LinkEditCard> {
  late TextEditingController _urlController;
  late String _selectedPlatform;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.link.url);
    _selectedPlatform = widget.link.platform;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF323232),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedPlatform,
                  decoration: const InputDecoration(
                    labelText: 'プラットフォーム',
                    border: OutlineInputBorder(),
                  ),
                  dropdownColor: const Color(0xFF323232),
                  items: widget.platforms.map((platform) {
                    return DropdownMenuItem(
                      value: platform,
                      child: Text(platform),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedPlatform = value;
                      });
                      widget.onChanged(
                        SnsLink(platform: value, url: _urlController.text),
                      );
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: widget.onRemove,
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://...',
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'URLを入力してください';
              }
              if (!value.startsWith('http://') && !value.startsWith('https://')) {
                return '有効なURLを入力してください';
              }
              return null;
            },
            onChanged: (value) {
              widget.onChanged(
                SnsLink(platform: _selectedPlatform, url: value),
              );
            },
          ),
        ],
      ),
    );
  }
}
```

---

## Google Play Console設定

### 1. アプリ内課金の有効化

1. **Google Play Console**にアクセス
2. アプリを選択
3. **収益化 → プロダクト → サブスクリプション**

### 2. サブスクリプション商品の作成

#### ベーシックプラン
- **プロダクトID**: `basic_monthly`
- **名前**: ガチトレ ベーシックプラン
- **説明**: プロフィールにSNS URLを表示、他ユーザーの食事メニュー閲覧
- **価格**: ¥1,000
- **請求期間**: 1ヶ月
- **無料トライアル**: なし（オプション）
- **特典期間**: なし

#### プレミアムプラン
- **プロダクトID**: `premium_monthly`
- **名前**: ガチトレ プレミアムプラン
- **説明**: ベーシック機能 + ログイン状態確認 + ブロック機能
- **価格**: ¥3,000
- **請求期間**: 1ヶ月
- **無料トライアル**: なし（オプション）
- **特典期間**: なし

### 3. テスター設定

1. **テストの設定 → ライセンステスト**
2. テスターのGoogleアカウントを追加
3. テスト用応答を「購入済み」に設定

---

## テスト手順

### 1. サンドボックステスト

```bash
# テスト用ビルド
flutter build appbundle --release

# テスターアカウントでGoogle Playからインストール
# サブスクリプション購入をテスト
```

### 2. テストシナリオ

#### ✅ 購入フロー
1. アプリ起動 → 設定 → プラン変更
2. ベーシックプランを選択
3. Google Play購入画面でテスト購入
4. 購入完了後、プロフィール編集でSNSリンク追加可能か確認

#### ✅ 機能制限
1. 無料プランでSNSリンク編集を試す → エラー表示
2. 無料プランで他ユーザーの食事閲覧 → プレミアム誘導
3. ベーシックプランでブロック機能 → エラー表示

#### ✅ 復元
1. アプリをアンインストール
2. 再インストール
3. 「購入を復元」をタップ
4. サブスクリプションが復元されるか確認

#### ✅ 有効期限
1. テスト用サブスクリプションの有効期限（5分など）を待つ
2. 期限切れ後、プレミアム機能が使えなくなるか確認

---

## リリース手順

### 1. バックエンドデプロイ

```bash
# Rust APIをデプロイ
cd services/api_rust
fly deploy
```

### 2. データベースマイグレーション

```bash
# Supabaseでマイグレーション実行
cd supabase
supabase db push
```

### 3. フロントエンドビルド

```bash
cd apps/mobile_flutter
flutter clean
flutter pub get
flutter build appbundle --release
```

### 4. Google Play Consoleにアップロード

1. 生成されたAABをアップロード
2. リリースノートに課金機能追加を記載
3. 段階的公開（10% → 50% → 100%）

### 5. モニタリング

- Google Play Console → 収益レポート
- Supabase → user_subscriptionsテーブル
- エラーログ監視（Sentry等）

---

## セキュリティ考慮事項

### ✅ 実装済み
- JWT認証によるAPI保護
- RLSによるデータアクセス制御
- サブスクリプション検証（サーバーサイド）

### ⚠️ 追加推奨
- Google Play Billing API検証の実装
- 購入トークンの署名検証
- レート制限（購入検証API）
- 不正購入の検出とブロック

---

## 今後の拡張

### Phase 2機能
- 年間プラン（20%割引）
- 無料トライアル（7日間）
- 紹介プログラム
- ギフトサブスクリプション

### Phase 3機能
- 企業向けプラン
- トレーナー認証プラン
- コンテンツ販売（買い切り）

---

## FAQ

### Q: 購入がうまくいかない
A:
1. Google Playのキャッシュクリア
2. アプリの再起動
3. 「購入を復元」を試す
4. テスターアカウントで正しくログインしているか確認

### Q: サブスクリプションがキャンセルできない
A: Google Playのサブスクリプション管理から直接キャンセル可能

### Q: 有効期限が切れたのに機能が使える
A:
1. アプリを再起動
2. バックエンドのcron jobで期限切れチェックが必要

---

## 実装チェックリスト

### データベース
- [ ] user_subscriptions テーブル作成
- [ ] user_profiles に subscription_tier 追加
- [ ] user_blocks テーブル作成
- [ ] RLSポリシー設定
- [ ] インデックス作成

### バックエンド
- [ ] サブスクリプション検証API
- [ ] 購入検証エンドポイント
- [ ] ブロック機能API
- [ ] SNSリンク更新API

### フロントエンド
- [ ] in_app_purchase 統合
- [ ] サブスクリプション画面
- [ ] 購入フロー実装
- [ ] プレミアム機能のUI制御
- [ ] SNSリンク編集画面
- [ ] ブロック機能UI

### Google Play
- [ ] サブスクリプション商品作成
- [ ] テスターアカウント設定
- [ ] 価格設定

### テスト
- [ ] サンドボックステスト
- [ ] 購入フロー
- [ ] 復元機能
- [ ] 機能制限

### リリース
- [ ] 本番環境デプロイ
- [ ] ドキュメント作成
- [ ] モニタリング設定
- [ ] Google Play公開

---

## 参考リンク

- [Flutter In-App Purchase](https://pub.dev/packages/in_app_purchase)
- [Google Play Billing](https://developer.android.com/google/play/billing)
- [Supabase RLS](https://supabase.com/docs/guides/auth/row-level-security)
- [RevenueCat](https://www.revenuecat.com/) (オプション)
