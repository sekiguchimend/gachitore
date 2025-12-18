## 目的

このアプリは **Supabase Auth** の `access_token` / `refresh_token` を使います。
要件「セッションが切れない（最低1カ月維持）」を満たすために、クライアント側で **自動refresh** を行い、Supabase側で **refresh token の有効期限** を1カ月以上に設定します。

## 実装（アプリ側）

- **起動時にセッション復元**: `ApiClient.ensureValidSession()` が `refresh_token` を使って `access_token` を復元します
- **期限前に自動refresh**: JWTの `exp` を見て、期限が近づくと自動で refresh します
- **ログイン画面スキップ**: `GoRouter` は初期表示を `/home` にし、未ログイン時だけ `/login` に戻します

該当コード:
- `apps/mobile_flutter/lib/core/api/api_client.dart`
- `apps/mobile_flutter/lib/core/router/app_router.dart`
- `apps/mobile_flutter/lib/core/auth/jwt_utils.dart`

## Supabase側の設定（重要）

アプリ側でどれだけ refresh しても、**Supabase側で refresh token の有効期限が短い** と「1カ月維持」できません。

Supabase Dashboard で以下を確認・設定してください（名称は画面で多少異なります）:

- **Refresh token expiration**: `2592000` 秒（= 30日）以上
- **Refresh token rotation**: 有効（推奨）
- **JWT expiry（access token）**: 例 `3600` 秒（= 1時間）でOK（短くても自動refreshで補えます）

これで「最後の利用から最大1カ月間はログインを維持」できます。


