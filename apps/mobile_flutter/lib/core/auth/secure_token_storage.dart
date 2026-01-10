import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_storage_keys.dart';

/// Secure storage for authentication tokens.
/// Uses flutter_secure_storage for encrypted storage on device.
///
/// Security settings:
/// - Android: Uses EncryptedSharedPreferences (AES-256-GCM)
/// - iOS: Uses Keychain with first_unlock_this_device accessibility
///
/// iOS Keychain Accessibility Options:
/// - first_unlock_this_device: Accessible after first device unlock, not synced to iCloud
///   (Chosen for balance between security and background token refresh capability)
/// - when_unlocked_this_device: Only when device is unlocked (more secure, but blocks background refresh)
/// - when_passcode_set_this_device: Only when passcode is set (most secure, but fails on devices without passcode)
class SecureTokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      // Use EncryptedSharedPreferences for Android 6.0+ (API 23+)
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      // first_unlock_this_device: Secure storage that allows background token refresh
      // Data is encrypted and not synced to iCloud Keychain
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _migrationKey = 'secure_storage_migrated';

  /// Migrate tokens from SharedPreferences to SecureStorage (one-time)
  static Future<void> migrateFromSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if already migrated
    if (prefs.getBool(_migrationKey) == true) {
      return;
    }

    // Migrate tokens
    final accessToken = prefs.getString(AuthStorageKeys.accessToken);
    final refreshToken = prefs.getString(AuthStorageKeys.refreshToken);
    final userId = prefs.getString(AuthStorageKeys.userId);
    final userEmail = prefs.getString(AuthStorageKeys.userEmail);

    if (accessToken != null) {
      await _storage.write(key: AuthStorageKeys.accessToken, value: accessToken);
      await prefs.remove(AuthStorageKeys.accessToken);
    }
    if (refreshToken != null) {
      await _storage.write(key: AuthStorageKeys.refreshToken, value: refreshToken);
      await prefs.remove(AuthStorageKeys.refreshToken);
    }
    if (userId != null) {
      await _storage.write(key: AuthStorageKeys.userId, value: userId);
      await prefs.remove(AuthStorageKeys.userId);
    }
    if (userEmail != null) {
      await _storage.write(key: AuthStorageKeys.userEmail, value: userEmail);
      await prefs.remove(AuthStorageKeys.userEmail);
    }

    // Mark as migrated
    await prefs.setBool(_migrationKey, true);
  }

  // Access Token
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: AuthStorageKeys.accessToken);
  }

  static Future<void> setAccessToken(String token) async {
    await _storage.write(key: AuthStorageKeys.accessToken, value: token);
  }

  static Future<void> deleteAccessToken() async {
    await _storage.delete(key: AuthStorageKeys.accessToken);
  }

  // Refresh Token
  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: AuthStorageKeys.refreshToken);
  }

  static Future<void> setRefreshToken(String token) async {
    await _storage.write(key: AuthStorageKeys.refreshToken, value: token);
  }

  static Future<void> deleteRefreshToken() async {
    await _storage.delete(key: AuthStorageKeys.refreshToken);
  }

  // User ID
  static Future<String?> getUserId() async {
    return await _storage.read(key: AuthStorageKeys.userId);
  }

  static Future<void> setUserId(String userId) async {
    await _storage.write(key: AuthStorageKeys.userId, value: userId);
  }

  static Future<void> deleteUserId() async {
    await _storage.delete(key: AuthStorageKeys.userId);
  }

  // User Email
  static Future<String?> getUserEmail() async {
    return await _storage.read(key: AuthStorageKeys.userEmail);
  }

  static Future<void> setUserEmail(String email) async {
    await _storage.write(key: AuthStorageKeys.userEmail, value: email);
  }

  static Future<void> deleteUserEmail() async {
    await _storage.delete(key: AuthStorageKeys.userEmail);
  }

  /// Clear all auth-related data
  static Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: AuthStorageKeys.accessToken),
      _storage.delete(key: AuthStorageKeys.refreshToken),
      _storage.delete(key: AuthStorageKeys.userId),
      _storage.delete(key: AuthStorageKeys.userEmail),
    ]);
  }

  /// Check if user has stored credentials
  static Future<bool> hasCredentials() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}
