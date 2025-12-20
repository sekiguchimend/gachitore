# gachitore

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## 通知（Push）設定

設定画面の「通知」スイッチで、Push通知が**届く/届かない**を切り替えられます。

- **ON**: 通知権限を確認し、許可されていれば端末トークンをサーバーへ登録します
- **OFF**: サーバーから端末トークンを削除し、Push送信対象から外します（=実際に届かない）

手動確認:

- 設定 > 通知をOFF → `user_push_tokens` からトークンが消えること / Pushが来ないこと
- 設定 > 通知をON → 権限許可後に `user_push_tokens` にトークンが登録されること
