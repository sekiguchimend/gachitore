import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/dashboard_service.dart';
import '../../data/services/workout_service.dart';
import '../../data/services/meal_service.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/board_service.dart';
import '../../data/services/push_notification_service.dart';
import '../../data/services/app_settings_service.dart';
import '../../data/services/support_service.dart';
import '../../data/services/subscription_service.dart';
import '../../data/services/iap_service.dart';
import '../../data/models/subscription_models.dart';

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

// Board service provider (掲示板)
final boardServiceProvider = Provider<BoardService>((ref) {
  return BoardService(
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

// Subscription service provider
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService(
    apiClient: ref.watch(apiClientProvider),
  );
});

// IAP service provider
final iapServiceProvider = Provider<IapService>((ref) {
  return IapService();
});

// Current user subscription provider
final currentSubscriptionProvider = FutureProvider<UserSubscription?>((ref) async {
  try {
    return await ref.read(subscriptionServiceProvider).getMySubscription();
  } catch (e) {
    return null;
  }
});

// Subscription tier provider - シンプルなFutureProviderに変更
// StreamProviderは依存関係変更時に再起動してUIがバグるため使わない
final subscriptionTierProvider = FutureProvider<SubscriptionTier>((ref) async {
  try {
    final subscription = await ref.read(subscriptionServiceProvider).getMySubscription();
    return subscription?.tier ?? SubscriptionTier.free;
  } catch (e) {
    return SubscriptionTier.free;
  }
});

// Blocked users provider
final blockedUsersProvider = FutureProvider<List<String>>((ref) async {
  try {
    return await ref.watch(subscriptionServiceProvider).getBlockedUsers();
  } catch (e) {
    return [];
  }
});
