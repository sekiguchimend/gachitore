import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/dashboard_service.dart';
import '../../data/services/workout_service.dart';
import '../../data/services/meal_service.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/photo_service.dart';
import '../../data/services/push_notification_service.dart';
import '../../data/services/app_settings_service.dart';
import '../../data/services/support_service.dart';

// API client provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

// Auth service provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    apiClient: ref.watch(apiClientProvider),
  );
});

// Dashboard service provider
final dashboardServiceProvider = Provider<DashboardService>((ref) {
  return DashboardService(
    apiClient: ref.watch(apiClientProvider),
  );
});

// Workout service provider
final workoutServiceProvider = Provider<WorkoutService>((ref) {
  return WorkoutService(
    apiClient: ref.watch(apiClientProvider),
  );
});

// Meal service provider
final mealServiceProvider = Provider<MealService>((ref) {
  return MealService(
    apiClient: ref.watch(apiClientProvider),
  );
});

// AI service provider
final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(
    apiClient: ref.watch(apiClientProvider),
  );
});

// Photo service provider
final photoServiceProvider = Provider<PhotoService>((ref) {
  return PhotoService(
    apiClient: ref.watch(apiClientProvider),
  );
});

// Push notification service provider (FCM token sync)
final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(
    apiClient: ref.watch(apiClientProvider),
  );
});

// App settings (local persistence)
final appSettingsServiceProvider = Provider<AppSettingsService>((ref) {
  return AppSettingsService();
});

// Support service provider
final supportServiceProvider = Provider<SupportService>((ref) {
  return SupportService(
    apiClient: ref.watch(apiClientProvider),
  );
});

// Auth state provider - checks if user is authenticated
final isAuthenticatedProvider = FutureProvider<bool>((ref) async {
  return await ref.watch(authServiceProvider).isAuthenticated;
});

// Current user ID provider
final currentUserIdProvider = FutureProvider<String?>((ref) async {
  return await ref.watch(authServiceProvider).currentUserId;
});
