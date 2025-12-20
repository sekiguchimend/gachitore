import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../firebase_options.dart';

class PushNotificationService {
  final ApiClient _apiClient;

  PushNotificationService({required ApiClient apiClient}) : _apiClient = apiClient;

  static bool _firebaseInitialized = false;

  Future<void> initializeFirebaseIfNeeded() async {
    if (_firebaseInitialized) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      _firebaseInitialized = true;
    } catch (e) {
      // linux等、未設定プラットフォームでは例外になるので無視
      if (kDebugMode) {
        debugPrint('[Push] Firebase initialize skipped: $e');
      }
    }
  }

  Future<void> initializeMessaging() async {
    await initializeFirebaseIfNeeded();
    if (!_firebaseInitialized) return;

    try {
      await FirebaseMessaging.instance.requestPermission();
      await FirebaseMessaging.instance.setAutoInitEnabled(true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Push] Messaging init failed: $e');
      }
    }
  }

  Future<bool> requestPermissionAndEnableAutoInit() async {
    await initializeFirebaseIfNeeded();
    if (!_firebaseInitialized) return false;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      final status = settings.authorizationStatus;
      final allowed = status == AuthorizationStatus.authorized ||
          status == AuthorizationStatus.provisional;

      if (!allowed) return false;

      await FirebaseMessaging.instance.setAutoInitEnabled(true);
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Push] requestPermission failed: $e');
      }
      return false;
    }
  }

  Future<void> syncToken({String? platform}) async {
    await initializeMessaging();
    if (!_firebaseInitialized) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      await _apiClient.post(
        '/users/push-token',
        data: {
          'token': token,
          if (platform != null) 'platform': platform,
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Push] syncToken failed: $e');
      }
    }
  }

  Future<void> deleteCurrentTokenFromServer() async {
    await initializeFirebaseIfNeeded();
    if (!_firebaseInitialized) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;

      await _apiClient.delete(
        '/users/push-token',
        data: {'token': token},
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Push] deleteCurrentTokenFromServer failed: $e');
      }
    }
  }

  Future<void> disablePush() async {
    // サーバー側の送信対象から外す（=実際に届かない）
    await deleteCurrentTokenFromServer();

    // 端末側も可能な範囲で無効化（best-effort）
    await initializeFirebaseIfNeeded();
    if (!_firebaseInitialized) return;

    try {
      await FirebaseMessaging.instance.setAutoInitEnabled(false);
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Push] disablePush failed: $e');
      }
    }
  }

  Future<void> initializeAndSync({String? platform}) async {
    // 画面遷移を止めない
    unawaited(syncToken(platform: platform));
  }

  Future<bool> enablePushAndSync({String? platform}) async {
    final ok = await requestPermissionAndEnableAutoInit();
    if (!ok) return false;

    await syncToken(platform: platform);
    return true;
  }
}


