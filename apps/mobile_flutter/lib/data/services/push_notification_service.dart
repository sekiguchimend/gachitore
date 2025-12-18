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

  Future<void> initializeAndSync({String? platform}) async {
    // 画面遷移を止めない
    unawaited(syncToken(platform: platform));
  }
}


