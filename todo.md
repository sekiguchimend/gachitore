

# ページ2：実装チェックリスト（そのままタスク分解に使う）

## A. Supabase（SQL / migrations）

* [ ] すべてのテーブルDDL作成（user_profiles, body_metrics, workouts, exercises, workout_exercises, workout_sets, meals, meal_items, nutrition_daily, ai_sessions, ai_messages, ai_recommendations）
* [ ] すべての必須インデックス作成
* [ ] 全テーブルでRLS有効化
* [ ] `user_id`直参照テーブルの SELECT/INSERT/UPDATE/DELETE ポリシー作成
* [ ] `workout_sets` のRLS方針決定

  * [ ] 方針A：JOIN RLSで辿る
  * [ ] 方針B：SECURITY DEFINER RPCで insert/update（推奨）
* [ ] `nutrition_daily` 再計算（RPC or BFF集計）実装
* [ ] `exercises` 初期seed投入（主要種目＋同義語）

## B. Rust BFF（Axum）

* [ ] Rustプロジェクト作成、モジュール構成（auth/db/state/gemini/routes/models）
* [ ] ENV定義

  * [ ] SUPABASE_URL
  * [ ] SUPABASE_ANON_KEY（必要なら）
  * [ ] SUPABASE_SERVICE_ROLE_KEY（BFFのみ）
  * [ ] SUPABASE_JWKS_URL
  * [ ] GEMINI_API_KEY
* [ ] JWT検証ミドルウェア（kid→JWKS→署名検証→sub=user_id）
* [ ] DBアクセス実装（PostgREST or sqlx）
* [ ] `POST /v1/log/workout` 実装（整合性：workout→exercise→sets）
* [ ] `POST /v1/log/meal` 実装（meal→items）
* [ ] `GET /v1/dashboard/today` 実装（日次集計）
* [ ] State生成器（14日/7日集計＋e1RM推定）
* [ ] Geminiクライアント（JSON出力強制、タイムアウト、リトライ最小）
* [ ] `POST /v1/ai/ask` 実装（保存：ai_sessions/messages/recommendations）
* [ ] `POST /v1/ai/plan/today` 実装（保存含む）
* [ ] 出力ガード（危険減量/医療/薬物/怪我放置→修正 or 警告）
* [ ] logging/tracing（リクエストID、遅延、失敗理由）
* [ ] Rustテスト

  * [ ] e1RM計算テスト
  * [ ] 集計（部位セット数）テスト
  * [ ] AIレスポンスJSONパースの異常系テスト
  * [ ] JWT検証の失敗系テスト

## C. Flutter（MVP）

* [ ] Supabase Authログイン（Email/Apple/Googleなど）
* [ ] BFFクライアント（Supabase access_token自動付与）
* [ ] freezedモデル定義（Workout/Meal/Dashboard/AiResponse）
* [ ] 画面実装（Onboarding/Dashboard/Workout/Meal/AI Coach）
* [ ] UX軽量化

  * [ ] 前回重量の自動サジェスト表示
  * [ ] RPEスライダー
  * [ ] 食事は写真だけで仮登録→後で詳細
* [ ] エラーハンドリング（通信失敗→再送・下書き）
* [ ] 最低限テスト（重要画面のwidget test 1-2本）

## D. ドキュメント（実装維持に必須）

* [ ] `docs/api.md`（エンドポイント/入出力JSON/エラー）
* [ ] `docs/state_schema.md`（StateV1のJSONスキーマ）
* [ ] `docs/rls.md`（RLS方針A/Bと採用理由）
