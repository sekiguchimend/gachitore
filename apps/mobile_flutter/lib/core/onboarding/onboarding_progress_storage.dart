import 'package:shared_preferences/shared_preferences.dart';
import '../api/api_client.dart';
import '../auth/secure_token_storage.dart';

/// オンボーディング（/setup）の進捗をローカルに保存し、
/// ルーターガードで「未完了なら /setup に固定」を実現するためのストレージ。
///
/// - ステップは 0..4 を想定
/// - 完了フラグは「完了APIが成功した」時点で true にする（オフライン復帰用）
class OnboardingProgressStorage {
  static const _stepKeyPrefix = 'onboarding_step_';
  static const _completedKeyPrefix = 'onboarding_completed_';

  static bool? _completedMemory;
  static DateTime? _lastRemoteCheckedAt;
  static Future<bool>? _completedInFlight;

  static String _stepKey(String userId) => '$_stepKeyPrefix$userId';
  static String _completedKey(String userId) => '$_completedKeyPrefix$userId';

  static Future<String?> _currentUserId() async {
    final id = await SecureTokenStorage.getUserId();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  static Future<int?> getSavedStep() async {
    final userId = await _currentUserId();
    if (userId == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final step = prefs.getInt(_stepKey(userId));
    if (step == null) return null;
    if (step < 0 || step > 4) return null;
    return step;
  }

  static Future<void> saveStep(int step) async {
    final userId = await _currentUserId();
    if (userId == null) return;

    final safe = step.clamp(0, 4);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stepKey(userId), safe);
  }

  static Future<void> clearStep() async {
    final userId = await _currentUserId();
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_stepKey(userId));
  }

  static Future<bool> getCompletedLocal() async {
    final userId = await _currentUserId();
    if (userId == null) return false;

    if (_completedMemory != null) return _completedMemory!;
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getBool(_completedKey(userId)) ?? false;
    _completedMemory = v;
    return v;
  }

  static Future<void> setCompletedLocal(bool value) async {
    final userId = await _currentUserId();
    if (userId == null) return;

    _completedMemory = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_completedKey(userId), value);
    if (value) {
      await prefs.remove(_stepKey(userId));
    }
  }

  /// 可能ならサーバーにも確認し、オンボーディング完了状態を返す。
  /// オフライン等で確認できない場合はローカル値を返す。
  ///
  /// `maxAge` 以内にサーバー確認済みなら、その間は再問い合わせしない。
  static Future<bool> getCompleted({
    Duration maxAge = const Duration(seconds: 30),
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final local = await getCompletedLocal();
    if (local) return true;

    final now = DateTime.now();
    if (_lastRemoteCheckedAt != null &&
        now.difference(_lastRemoteCheckedAt!) < maxAge) {
      return local;
    }

    _completedInFlight ??= _fetchCompletedRemote(timeout: timeout).whenComplete(() {
      _completedInFlight = null;
    });
    return _completedInFlight!;
  }

  static Future<bool> _fetchCompletedRemote({
    required Duration timeout,
  }) async {
    final userId = await _currentUserId();
    if (userId == null) return false;

    try {
      await ApiClient().initialize();
      final resp = await ApiClient()
          .get<Map<String, dynamic>>('/users/onboarding/status')
          .timeout(timeout);
      final completed = (resp.data?['completed'] == true);
      _lastRemoteCheckedAt = DateTime.now();
      await setCompletedLocal(completed);
      return completed;
    } catch (_) {
      _lastRemoteCheckedAt = DateTime.now();
      return await getCompletedLocal();
    }
  }

  /// ログアウト等でメモリキャッシュを初期化
  static void resetMemory() {
    _completedMemory = null;
    _lastRemoteCheckedAt = null;
    _completedInFlight = null;
  }
}


