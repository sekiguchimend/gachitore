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
      final response = await _apiClient.post(
        '/auth/signup',
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
    List<String>? equipment,
    List<String>? constraints,
    int? mealsPerDay,
  }) async {
    // 生年を計算 (DBはbirth_yearを期待)
    final birthYear = DateTime.now().year - age;

    // environmentをJSONB形式に変換
    final Map<String, dynamic> environmentJson = {
      'gym': environment == 'gym' || environment == 'both',
      'home': environment == 'home' || environment == 'both',
      'equipment': equipment ?? [],
    };

    // constraintsをJSONB形式に変換
    final List<Map<String, dynamic>> constraintsJson = (constraints ?? [])
        .map((c) => {'part': c, 'severity': 'mild'})
        .toList();
    
    try {
      await _apiClient.post(
        '/users/onboarding/complete',
        data: {
          'goal': goal,
          'training_level': level,  // DBカラム名に合わせる
          'height_cm': height.round(),  // DBカラム名に合わせる
          'birth_year': birthYear,  // DBカラム名に合わせる
          'sex': sex,
          'environment': environmentJson,  // JSONB形式
          'constraints': constraintsJson,  // JSONB形式
          'meals_per_day': mealsPerDay ?? 3,
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

  // Update user profile
  Future<void> updateProfile({
    String? displayName,
    String? goal,
    String? trainingLevel,
    String? sex,
    int? heightCm,
    int? birthYear,
    double? weightKg,
    Map<String, dynamic>? environment,
    List<Map<String, dynamic>>? constraints,
  }) async {
    final data = <String, dynamic>{};
    
    if (displayName != null) data['display_name'] = displayName;
    if (goal != null) data['goal'] = goal;
    if (trainingLevel != null) data['training_level'] = trainingLevel;
    if (sex != null) data['sex'] = sex;
    if (heightCm != null) data['height_cm'] = heightCm;
    if (birthYear != null) data['birth_year'] = birthYear;
    if (weightKg != null) data['weight_kg'] = weightKg;
    if (environment != null) data['environment'] = environment;
    if (constraints != null) data['constraints'] = constraints;

    try {
      await _apiClient.patch('/users/profile', data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // Save auth data to storage
  Future<void> _saveAuthData(AuthResponse response) async {
    final prefs = await _getPrefs();
    await prefs.setString(_accessTokenKey, response.accessToken);
    await prefs.setString(_refreshTokenKey, response.refreshToken);
    await prefs.setString(_userIdKey, response.user.id);
    await prefs.setString(_userEmailKey, response.user.email);
    await _apiClient.setToken(response.accessToken);
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
