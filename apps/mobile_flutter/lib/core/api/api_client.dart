import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../auth/jwt_utils.dart';
import '../auth/secure_token_storage.dart';

class ApiClient {
  static const String _baseUrlKey = 'api_base_url';

  // Production API URL - HTTPS required
  static const String _prodBaseUrl = 'https://gachitore.fly.dev/v1';
  // Development API URL
  static const String _devBaseUrl = 'http://localhost:8080/v1';

  late final Dio _dio;
  SharedPreferences? _prefs;
  Future<void>? _initFuture;
  Future<bool>? _refreshFuture;
  Timer? _autoRefreshTimer;

  // Callback for when refresh fails and user needs to re-login
  void Function()? onAuthenticationFailed;

  // Singleton
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  ApiClient._internal() {
    // Use HTTPS in release mode, HTTP only for development
    final defaultBaseUrl = kReleaseMode ? _prodBaseUrl : _devBaseUrl;

    _dio = Dio(BaseOptions(
      baseUrl: defaultBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add auth token if available (from secure storage)
        final token = await SecureTokenStorage.getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 - token expired, try to refresh
        if (error.response?.statusCode == 401) {
          final requestOptions = error.requestOptions;

          // Don't try to refresh if this is the refresh request itself
          if (requestOptions.path.contains('/auth/refresh')) {
            return handler.next(error);
          }

          // Try to refresh the token
          final refreshed = await _tryRefreshToken();

          if (refreshed) {
            // Retry the original request with new token
            try {
              final newToken = await SecureTokenStorage.getAccessToken();
              requestOptions.headers['Authorization'] = 'Bearer $newToken';

              final response = await _dio.fetch(requestOptions);
              return handler.resolve(response);
            } catch (e) {
              return handler.next(error);
            }
          } else {
            // Refresh failed, clear all tokens and notify
            await _clearAllTokens();
            onAuthenticationFailed?.call();
          }
        }
        return handler.next(error);
      },
    ));
  }

  /// Try to refresh the access token using refresh token
  Future<bool> _tryRefreshToken() async {
    // Prevent multiple simultaneous refresh attempts.
    // NOTE: Previously this used a Completer but never completed it, which could deadlock
    // if a second refresh attempt awaited the same future.
    _refreshFuture ??= _performRefreshToken().whenComplete(() {
      _refreshFuture = null;
    });
    return _refreshFuture!;
  }

  Future<bool> _performRefreshToken() async {
    try {
      await initialize();
      final refreshToken = await SecureTokenStorage.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        return false;
      }

      // Make refresh request without interceptor to avoid infinite loop
      final response = await Dio(BaseOptions(
        baseUrl: _dio.options.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      )).post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200 && response.data != null) {
        final newAccessToken = response.data['access_token'];
        final newRefreshToken = response.data['refresh_token'];

        if (newAccessToken != null) {
          await SecureTokenStorage.setAccessToken(newAccessToken);

          // Also update refresh token if provided
          if (newRefreshToken != null) {
            await SecureTokenStorage.setRefreshToken(newRefreshToken);
          }

          return true;
        }
      }

      return false;
    } catch (e) {
      // Keep this best-effort (no throw), but log for diagnostics.
      try {
        // ignore: avoid_print
        print('[ApiClient] refresh token failed: $e');
      } catch (_) {}
      return false;
    }
  }

  /// 起動時/復帰時に呼ぶ想定:
  /// - access_token が有効なら true
  /// - access_token が無効/未保存でも refresh_token があれば refresh して true を返す
  /// - どちらもダメなら false
  Future<bool> ensureValidSession({
    Duration leeway = const Duration(minutes: 2),
  }) async {
    await initialize();
    final accessToken = await SecureTokenStorage.getAccessToken();
    final refreshToken = await SecureTokenStorage.getRefreshToken();

    final isAccessValid = accessToken != null &&
        accessToken.isNotEmpty &&
        !JwtUtils.isExpiringSoon(accessToken, leeway: leeway);

    if (isAccessValid) {
      startAutoRefresh(leeway: leeway);
      return true;
    }

    // access_token が無い/期限切れでも refresh_token があれば復元を試みる
    if (refreshToken != null && refreshToken.isNotEmpty) {
      final ok = await _tryRefreshToken();
      if (ok) {
        startAutoRefresh(leeway: leeway);
        return true;
      }

      // Refresh failed: clear tokens so the app can fall back to login cleanly.
      await _clearAllTokens();
      onAuthenticationFailed?.call();
      return false;
    }

    stopAutoRefresh();
    return false;
  }

  /// access_token の exp を見て、期限が近づいたら自動で refresh する
  void startAutoRefresh({
    Duration leeway = const Duration(minutes: 2),
  }) {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;

    _scheduleNextAutoRefresh(leeway: leeway);
  }

  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  Future<void> _scheduleNextAutoRefresh({
    required Duration leeway,
  }) async {
    final token = await SecureTokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    final exp = JwtUtils.tryGetExpiry(token);
    if (exp == null) return;

    final now = DateTime.now();
    // 期限の leeway より前（= exp - leeway）に refresh
    final refreshAt = exp.subtract(leeway);
    final delay = refreshAt.difference(now);

    // すぐ/過去なら即時実行（ただしスパム回避で最低30秒）
    final safeDelay = delay.isNegative ? const Duration(seconds: 30) : delay;

    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer(safeDelay, () async {
      final ok = await _tryRefreshToken();
      if (!ok) {
        await _clearAllTokens();
        onAuthenticationFailed?.call();
        return;
      }
      // refresh 成功したら次を再スケジュール
      await _scheduleNextAutoRefresh(leeway: leeway);
    });
  }

  /// Clear all auth tokens
  Future<void> _clearAllTokens() async {
    await SecureTokenStorage.clearAll();
    stopAutoRefresh();
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> setBaseUrl(String url) async {
    // Security: In release mode, only allow HTTPS URLs
    if (kReleaseMode && !url.startsWith('https://')) {
      throw ApiException(
        message: 'HTTPS is required in production',
        statusCode: 400,
      );
    }

    final prefs = await _getPrefs();
    await prefs.setString(_baseUrlKey, url);
    _dio.options.baseUrl = url;
  }

  Future<void> initialize() async {
    // Idempotent: safe to call multiple times / from multiple code paths.
    _initFuture ??= _initializeInternal().whenComplete(() {
      _initFuture = null;
    });
    await _initFuture!;
  }

  Future<void> _initializeInternal() async {
    final prefs = await _getPrefs();
    final baseUrl = prefs.getString(_baseUrlKey);
    if (baseUrl != null && baseUrl.isNotEmpty) {
      _dio.options.baseUrl = baseUrl;
    }
  }

  Future<void> setToken(String token) async {
    await SecureTokenStorage.setAccessToken(token);
  }

  Future<void> clearToken() async {
    await SecureTokenStorage.deleteAccessToken();
  }

  Future<String?> getToken() async {
    return await SecureTokenStorage.getAccessToken();
  }

  // GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }

  // PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
  }
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  factory ApiException.fromDioError(DioException error) {
    String message;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = '接続がタイムアウトしました';
        break;
      case DioExceptionType.badResponse:
        final data = error.response?.data;
        if (data is Map<String, dynamic>) {
          message = data['message']?.toString() ?? 'サーバーエラーが発生しました';
        } else if (data is String) {
          message = data;
        } else {
          message = 'サーバーエラーが発生しました';
        }
        break;
      case DioExceptionType.cancel:
        message = 'リクエストがキャンセルされました';
        break;
      default:
        message = 'ネットワークエラーが発生しました';
    }

    return ApiException(
      message: message,
      statusCode: error.response?.statusCode,
      data: error.response?.data,
    );
  }

  @override
  String toString() => message;
}
