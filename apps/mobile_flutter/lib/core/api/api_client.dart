import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const String _baseUrlKey = 'api_base_url';
  static const String _tokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  late final Dio _dio;
  SharedPreferences? _prefs;
  bool _isRefreshing = false;

  // Callback for when refresh fails and user needs to re-login
  void Function()? onAuthenticationFailed;

  // Singleton
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add auth token if available
        final prefs = await _getPrefs();
        final token = prefs.getString(_tokenKey);
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
              final prefs = await _getPrefs();
              final newToken = prefs.getString(_tokenKey);
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
    // Prevent multiple simultaneous refresh attempts
    if (_isRefreshing) {
      return false;
    }

    _isRefreshing = true;

    try {
      final prefs = await _getPrefs();
      final refreshToken = prefs.getString(_refreshTokenKey);

      if (refreshToken == null || refreshToken.isEmpty) {
        print('[ApiClient] No refresh token available');
        return false;
      }

      print('[ApiClient] Attempting to refresh token...');

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
          await prefs.setString(_tokenKey, newAccessToken);
          print('[ApiClient] Access token refreshed successfully');

          // Also update refresh token if provided
          if (newRefreshToken != null) {
            await prefs.setString(_refreshTokenKey, newRefreshToken);
            print('[ApiClient] Refresh token updated');
          }

          return true;
        }
      }

      print('[ApiClient] Token refresh failed - invalid response');
      return false;
    } catch (e) {
      print('[ApiClient] Token refresh failed: $e');
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Clear all auth tokens
  Future<void> _clearAllTokens() async {
    final prefs = await _getPrefs();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    print('[ApiClient] All tokens cleared');
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> setBaseUrl(String url) async {
    final prefs = await _getPrefs();
    await prefs.setString(_baseUrlKey, url);
    _dio.options.baseUrl = url;
  }

  Future<void> initialize() async {
    final prefs = await _getPrefs();
    final baseUrl = prefs.getString(_baseUrlKey);
    if (baseUrl != null) {
      _dio.options.baseUrl = baseUrl;
    } else {
      // Default to localhost for development (Rust API on port 8080)
      _dio.options.baseUrl = 'http://localhost:8080/v1';
    }
  }

  Future<void> setToken(String token) async {
    final prefs = await _getPrefs();
    await prefs.setString(_tokenKey, token);
  }

  Future<void> clearToken() async {
    final prefs = await _getPrefs();
    await prefs.remove(_tokenKey);
  }

  Future<String?> getToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(_tokenKey);
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
