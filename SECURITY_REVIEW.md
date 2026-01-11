# サブスクリプションシステム セキュリティレビュー結果

実施日: 2026-01-11

## 概要

ユーザーからの要求「コードを徹底して見直して。変なバグで課金してないのにその機能が使えるみたいなことはないかとかしっかり確認して」に基づき、サブスクリプション機能の包括的なセキュリティレビューを実施しました。

## 🔴 致命的な脆弱性

### 1. 購入検証の未実装（CRITICAL）

**場所**: `services/api_rust/src/api/handlers/subscriptions.rs:89-90`

**問題**:
```rust
// TODO: Verify purchase with Google Play Billing API or App Store API
// For now, we'll trust the client (insecure - implement proper verification in production)
```

**影響**:
- ユーザーは偽の `purchase_token` を送信してプレミアム機能を無料で使用できる
- 収益損失の可能性が非常に高い
- 不正利用が容易に可能

**推奨される対策**:
1. Google Play Billing API を使用した購入トークンの検証を実装
2. Apple App Store Receipt Validation API の実装
3. サーバーサイドでの厳密な検証ロジック
4. 検証失敗時の適切なエラーハンドリング

**実装優先度**: 🔥 **即座に実装が必要**

## 🟡 修正済みの脆弱性

### 2. RLS ポリシーの脆弱性（修正済み）

**場所**: `supabase/migrations/20260111_fix_subscription_rls.sql`

**問題**:
- 元のRLSポリシーが `user_profiles.subscription_tier` をチェックしていた
- ユーザーが自分のプロファイルを更新して `subscription_tier` を変更できる可能性があった

**対策**:
1. ブロック機能のRLSポリシーを `user_subscriptions` テーブルをチェックするように変更
2. `status = 'active'` と `expires_at > now()` の両方を検証
3. ユーザーが `user_profiles.subscription_tier` を更新できないようにポリシーを追加

**修正内容**:
```sql
-- Premium users can manage blocks
create policy "Premium users can manage blocks"
  on public.user_blocks
  for all
  to authenticated
  using (
    auth.uid() = blocker_user_id
    and exists (
      select 1 from public.user_subscriptions
      where user_id = auth.uid()
        and subscription_tier = 'premium'
        and status = 'active'
        and expires_at > now()  -- 重要: 有効期限チェック
    )
  );

-- Prevent users from updating subscription_tier
create policy "Users can update own profile"
  on public.user_profiles
  for update
  to authenticated
  using (auth.uid() = user_id)
  with check (
    auth.uid() = user_id
    and old.subscription_tier = new.subscription_tier  -- 変更を防止
  );
```

**マイグレーション**: `20260111_fix_subscription_rls.sql` を適用する必要があります

## 🟢 実装された改善

### 3. 集中型サブスクリプションチェックモジュール

**場所**: `services/api_rust/src/api/subscription_check.rs`

**改善点**:
- サブスクリプションチェックロジックを単一のモジュールに集約
- コードの重複を排除
- 一貫性のある検証ロジック
- テストの追加

**リファクタリング完了**:
- ✅ `meals.rs`: 他ユーザーの食事メニュー閲覧（Basic+必須）
- ✅ `users.rs`: オンラインステータス更新（Premium必須）
- ✅ `subscriptions.rs`: SNSリンク機能（Basic+必須）、ブロック機能（Premium必須）

**使用例**:
```rust
crate::api::subscription_check::require_subscription(
    &state,
    &user.user_id,
    &user.token,
    crate::api::subscription_check::SubscriptionTier::Premium,
    "ユーザーブロック機能",
)
.await?;
```

## セキュリティチェックリスト

### バックエンド（Rust API）

| 機能 | サブスクチェック | ステータス | 備考 |
|------|-----------------|-----------|------|
| 購入検証 | N/A | ❌ 未実装 | **致命的**: 偽のトークンを受け入れる |
| 食事メニュー閲覧 | Basic+ | ✅ 実装済み | 集中型モジュール使用 |
| SNSリンク設定 | Basic+ | ✅ 実装済み | 集中型モジュール使用 |
| SNSリンク閲覧 | Basic+ | ✅ 実装済み | 集中型モジュール使用 |
| ユーザーブロック | Premium | ✅ 実装済み | 集中型モジュール使用 |
| オンラインステータス | Premium | ✅ 実装済み | 集中型モジュール使用 |

### データベース（RLS ポリシー）

| テーブル | ポリシー | ステータス | 備考 |
|---------|---------|-----------|------|
| user_blocks | Premium必須 | ⚠️ 要適用 | マイグレーション作成済み、適用待ち |
| user_profiles | subscription_tier保護 | ⚠️ 要適用 | ユーザーによる変更を防止 |
| user_subscriptions | 適切な権限 | ✅ 実装済み | ユーザーは自分のサブスクのみ閲覧可能 |

### フロントエンド（Flutter）

| 機能 | UIゲート | ステータス | 備考 |
|------|---------|-----------|------|
| ブロックボタン | Premium | ✅ 実装済み | `user_profile_page.dart` |
| SNSリンク表示 | Basic+ | ✅ 実装済み | SubscriptionGate使用 |
| 食事メニュー表示 | Basic+ | ✅ 実装済み | 403エラーハンドリング |
| オンラインステータス | Premium | ✅ 実装済み | UI表示のみ（更新は未実装） |
| プラン変更UI | N/A | ✅ 実装済み | 現在のプランを表示 |

## 推奨される次のステップ

### 優先度: 🔥 緊急（即座に対応が必要）

1. **Google Play 購入検証の実装**
   - Google Play Billing API の統合
   - `verify_purchase` エンドポイントでのトークン検証
   - 不正なトークンの拒否

### 優先度: 🟡 高（できるだけ早く対応）

2. **RLSマイグレーションの適用**
   ```bash
   supabase migration up
   # または
   psql -f supabase/migrations/20260111_fix_subscription_rls.sql
   ```

3. **エンドツーエンドテスト**
   - 無料ユーザーがBasic機能にアクセスできないことを確認
   - Basicユーザーがプレミアム機能にアクセスできないことを確認
   - 期限切れのサブスクリプションが拒否されることを確認

### 優先度: 🟢 中（改善として実施）

4. **監視とロギングの追加**
   - 不正なアクセス試行のログ
   - サブスクリプション検証失敗の追跡
   - アラート機能の実装

5. **Apple App Store 統合**
   - iOS購入の検証ロジック
   - レシート検証の実装

## 結論

**現在の状態**:
- ✅ バックエンドのサブスクリプションチェックは適切に実装されている
- ✅ フロントエンドのUI制御は実装されている
- ⚠️ RLSポリシーの修正が必要（マイグレーション作成済み、適用待ち）
- ❌ **購入検証が未実装 - これは致命的なセキュリティホール**

**総合評価**:
現時点では、バックエンドとフロントエンドのロジックは適切に実装されていますが、**購入検証の欠如により、誰でも偽のトークンを送信してプレミアム機能を無料で使用できる状態です**。これは即座に対応が必要な致命的な問題です。

RLSポリシーの修正は作成済みですが、データベースへの適用が必要です。
