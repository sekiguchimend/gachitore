import 'package:shared_preferences/shared_preferences.dart';

import '../auth/secure_token_storage.dart';

/// ホーム画面の簡易チャット履歴（端末キャッシュ）の保存/復元/削除を扱う。
///
/// 注意:
/// - これは「Supabase上の会話履歴」とは別物（UIの体験向上のための直近キャッシュ）
/// - アカウント切り替え時に混ざらないよう、ユーザーIDごとにキーを分ける
class ChatHistoryStorage {
  static const String _legacyKey = 'chat_history_v1';
  static const String _keyPrefix = 'chat_history_v1_';

  static Future<String> _currentKey() async {
    final userId = await SecureTokenStorage.getUserId();
    if (userId == null || userId.isEmpty) return _legacyKey;
    return '$_keyPrefix$userId';
  }

  /// 旧キー（ユーザー非依存）を、現在のユーザーキーへ移行し、旧キーを削除する。
  /// すでにユーザーキーが存在する場合は移行しない。
  static Future<void> migrateLegacyToCurrentUserIfNeeded() async {
    try {
      final userId = await SecureTokenStorage.getUserId();
      if (userId == null || userId.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final userKey = '$_keyPrefix$userId';
      final hasUserKey = prefs.containsKey(userKey);
      final legacy = prefs.getString(_legacyKey);

      if (!hasUserKey && legacy != null && legacy.isNotEmpty) {
        await prefs.setString(userKey, legacy);
      }

      if (prefs.containsKey(_legacyKey)) {
        await prefs.remove(_legacyKey);
      }
    } catch (_) {
      // ignore (best-effort)
    }
  }

  static Future<String?> getRaw() async {
    try {
      await migrateLegacyToCurrentUserIfNeeded();
      final prefs = await SharedPreferences.getInstance();
      final key = await _currentKey();
      return prefs.getString(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setRaw(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _currentKey();
      await prefs.setString(key, value);
    } catch (_) {
      // ignore (best-effort)
    }
  }

  /// ログアウト時などに、現在ユーザーのチャットキャッシュを削除する。
  ///
  /// `alsoClearLegacy` を true にすると、過去バージョンの旧キーも削除する。
  static Future<void> clearForCurrentUser({bool alsoClearLegacy = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _currentKey();
      await prefs.remove(key);
      if (alsoClearLegacy) {
        await prefs.remove(_legacyKey);
      }
    } catch (_) {
      // ignore (best-effort)
    }
  }
}


