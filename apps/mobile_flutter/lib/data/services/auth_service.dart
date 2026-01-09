import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/auth/secure_token_storage.dart';

class AuthService {
  final ApiClient _apiClient;

  AuthService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  // Check if user is authenticated
  Future<bool> get isAuthenticated async {
    return await SecureTokenStorage.hasCredentials();
  }

  // Get current user ID
  Future<String?> get currentUserId async {
    return await SecureTokenStorage.getUserId();
  }

  // Get current user email
  Future<String?> get currentUserEmail async {
    return await SecureTokenStorage.getUserEmail();
  }

  // Get current token
  Future<String?> getToken() async {
    return await SecureTokenStorage.getAccessToken();
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
    final refreshToken = await SecureTokenStorage.getRefreshToken();
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
          'weight_kg': weight, // 体重も送る（body_metrics の登録に必要）
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
    int? targetCalories,
    int? targetProteinG,
    int? targetFatG,
    int? targetCarbsG,
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
    if (targetCalories != null) data['target_calories'] = targetCalories;
    if (targetProteinG != null) data['target_protein_g'] = targetProteinG;
    if (targetFatG != null) data['target_fat_g'] = targetFatG;
    if (targetCarbsG != null) data['target_carbs_g'] = targetCarbsG;

    try {
      await _apiClient.patch('/users/profile', data: data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // Upload avatar image
  Future<String> uploadAvatar(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final filename = file.name.isNotEmpty ? file.name : 'avatar.jpg';

      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      });

      // Note: Do NOT set Content-Type manually - Dio will set it with the correct boundary
      final res = await _apiClient.post(
        '/users/avatar',
        data: form,
      );

      return res.data['avatar_url'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // Save auth data to secure storage
  Future<void> _saveAuthData(AuthResponse response) async {
    await SecureTokenStorage.setAccessToken(response.accessToken);
    await SecureTokenStorage.setRefreshToken(response.refreshToken);
    await SecureTokenStorage.setUserId(response.user.id);
    await SecureTokenStorage.setUserEmail(response.user.email);
    await _apiClient.setToken(response.accessToken);
  }

  // Clear auth data from secure storage
  Future<void> _clearAuthData() async {
    await SecureTokenStorage.clearAll();
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
