import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';

class AuthService {
  final ApiClient _apiClient;
  SharedPreferences? _prefs;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';

  AuthService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Check if user is authenticated
  Future<bool> get isAuthenticated async {
    final prefs = await _getPrefs();
    final token = prefs.getString(_accessTokenKey);
    return token != null;
  }

  // Get current user ID
  Future<String?> get currentUserId async {
    final prefs = await _getPrefs();
    return prefs.getString(_userIdKey);
  }

  // Get current user email
  Future<String?> get currentUserEmail async {
    final prefs = await _getPrefs();
    return prefs.getString(_userEmailKey);
  }

  // Get current token
  Future<String?> getToken() async {
    final prefs = await _getPrefs();
    return prefs.getString(_accessTokenKey);
  }

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    try {
      print('[AuthService] Starting signup for $email');
      final response = await _apiClient.post(
        '/auth/signup',
        data: {
          'email': email,
          'password': password,
        },
      );

      print('[AuthService] Signup response received');
      final authResponse = AuthResponse.fromJson(response.data);
      print('[AuthService] Parsed response, access_token present: ${authResponse.accessToken.isNotEmpty}');
      await _saveAuthData(authResponse);
      return authResponse;
    } on DioException catch (e) {
      print('[AuthService] Signup error: ${e.message}');
      throw _handleAuthError(e);
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/signin',
        data: {
          'email': email,
          'password': password,
        },
      );

      final authResponse = AuthResponse.fromJson(response.data);
      await _saveAuthData(authResponse);
      return authResponse;
    } on DioException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Sign in with Google (not supported via API - would need OAuth flow)
  Future<bool> signInWithGoogle() async {
    throw UnimplementedError('Google sign-in requires OAuth flow');
  }

  // Sign in with Apple (not supported via API - would need OAuth flow)
  Future<bool> signInWithApple() async {
    throw UnimplementedError('Apple sign-in requires OAuth flow');
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _apiClient.post('/auth/signout');
    } catch (_) {
      // Ignore errors on signout
    }
    await _clearAuthData();
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _apiClient.post(
        '/auth/password/reset',
        data: {'email': email},
      );
    } on DioException catch (e) {
      throw _handleAuthError(e);
    }
  }

  // Refresh session
  Future<void> refreshSession() async {
    final prefs = await _getPrefs();
    final refreshToken = prefs.getString(_refreshTokenKey);
    if (refreshToken == null) {
      throw Exception('No refresh token available');
    }

    try {
      final response = await _apiClient.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final authResponse = AuthResponse.fromJson(response.data);
      await _saveAuthData(authResponse);
    } on DioException catch (e) {
      await _clearAuthData();
      throw _handleAuthError(e);
    }
  }

  // Check if onboarding is completed
  Future<bool> isOnboardingCompleted() async {
    try {
      final response = await _apiClient.get('/users/onboarding/status');
      return response.data['completed'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // Complete onboarding
  Future<void> completeOnboarding({
    required String goal,
    required String level,
    required double weight,
    required double height,
    required int age,
    required String sex,
    String? environment,
    List<String>? constraints,
  }) async {
    // DEBUG: Check token before request
    final prefs = await _getPrefs();
    final token = prefs.getString(_accessTokenKey);
    print('[AuthService] completeOnboarding - Token from storage: ${token != null ? "present (${token.length} chars)" : "NULL!!!"}');
    final apiToken = await _apiClient.getToken();
    print('[AuthService] completeOnboarding - Token from ApiClient: ${apiToken != null ? "present (${apiToken.length} chars)" : "NULL!!!"}');
    
    try {
      await _apiClient.post(
        '/users/onboarding/complete',
        data: {
          'goal': goal,
          'level': level,
          'weight': weight,
          'height': height,
          'age': age,
          'sex': sex,
          'environment': environment ?? 'gym',
          'constraints': constraints ?? [],
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final response = await _apiClient.get('/users/profile');
      return response.data;
    } catch (e) {
      return null;
    }
  }

  // Save auth data to storage
  Future<void> _saveAuthData(AuthResponse response) async {
    print('[AuthService] Saving auth data...');
    print('[AuthService] Access token length: ${response.accessToken.length}');
    final prefs = await _getPrefs();
    await prefs.setString(_accessTokenKey, response.accessToken);
    await prefs.setString(_refreshTokenKey, response.refreshToken);
    await prefs.setString(_userIdKey, response.user.id);
    await prefs.setString(_userEmailKey, response.user.email);
    await _apiClient.setToken(response.accessToken);

    // Verify token was saved
    final savedToken = prefs.getString(_accessTokenKey);
    print('[AuthService] Token saved and verified: ${savedToken != null ? "yes (${savedToken.length} chars)" : "NO!"}');
  }

  // Clear auth data from storage
  Future<void> _clearAuthData() async {
    final prefs = await _getPrefs();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await _apiClient.clearToken();
  }

  // Handle auth errors
  Exception _handleAuthError(DioException e) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final message = data['message'] ?? 'Authentication failed';
      return Exception(message);
    }
    return Exception('Authentication failed');
  }
}

// Auth response model
class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int expiresIn;
  final UserInfo user;

  AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      tokenType: json['token_type'] ?? 'Bearer',
      expiresIn: json['expires_in'] is int 
          ? json['expires_in'] 
          : int.tryParse(json['expires_in']?.toString() ?? '3600') ?? 3600,
      user: UserInfo.fromJson(json['user']),
    );
  }
}

class UserInfo {
  final String id;
  final String email;

  UserInfo({required this.id, required this.email});

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'],
      email: json['email'],
    );
  }
}
