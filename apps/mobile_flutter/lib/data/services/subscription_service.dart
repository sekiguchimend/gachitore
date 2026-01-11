import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../models/subscription_models.dart';

/// サブスクリプションサービス
class SubscriptionService {
  final ApiClient _apiClient;

  SubscriptionService({required ApiClient apiClient}) : _apiClient = apiClient;

  // ==========================================================================
  // Subscription Management
  // ==========================================================================

  /// 購入を検証してサブスクリプションを登録
  Future<UserSubscription> verifyPurchase({
    required String platform,
    required String productId,
    required String purchaseToken,
    String? transactionId,
  }) async {
    try {
      final res = await _apiClient.post(
        '/subscriptions/verify',
        data: {
          'platform': platform,
          'product_id': productId,
          'purchase_token': purchaseToken,
          if (transactionId != null) 'transaction_id': transactionId,
        },
      );
      return UserSubscription.fromJson(
        (res.data as Map<String, dynamic>)['subscription'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// 自分のサブスクリプション状態を取得
  Future<UserSubscription?> getMySubscription() async {
    try {
      final res = await _apiClient.get('/subscriptions/me');
      return UserSubscription.fromJson(
        (res.data as Map<String, dynamic>)['subscription'] as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      // 404の場合はnullを返す（サブスクなし）
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw ApiException.fromDioError(e);
    }
  }

  /// サブスクリプションをキャンセル
  Future<void> cancelSubscription() async {
    try {
      await _apiClient.delete('/subscriptions/me');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ==========================================================================
  // SNS Links (Basic/Premium feature)
  // ==========================================================================

  /// 自分のSNSリンクを更新
  Future<List<SnsLink>> updateMySnsLinks(List<SnsLink> snsLinks) async {
    try {
      final res = await _apiClient.post(
        '/users/me/sns-links',
        data: {
          'sns_links': snsLinks.map((link) => link.toJson()).toList(),
        },
      );
      final List<dynamic> linksJson =
          (res.data as Map<String, dynamic>)['sns_links'] as List<dynamic>;
      return linksJson
          .map((json) => SnsLink.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// 特定ユーザーのSNSリンクを取得
  Future<List<SnsLink>> getUserSnsLinks(String userId) async {
    try {
      final res = await _apiClient.get('/users/$userId/sns-links');
      final List<dynamic> linksJson =
          (res.data as Map<String, dynamic>)['sns_links'] as List<dynamic>;
      return linksJson
          .map((json) => SnsLink.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ==========================================================================
  // User Blocking (Premium feature)
  // ==========================================================================

  /// ユーザーをブロック
  Future<void> blockUser(String blockedUserId) async {
    try {
      await _apiClient.post(
        '/blocks',
        data: {'blocked_user_id': blockedUserId},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// ユーザーのブロックを解除
  Future<void> unblockUser(String blockedUserId) async {
    try {
      await _apiClient.delete('/blocks/$blockedUserId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// ブロックしたユーザーのリストを取得
  Future<List<String>> getBlockedUsers() async {
    try {
      final res = await _apiClient.get('/blocks');
      final List<dynamic> userIds =
          (res.data as Map<String, dynamic>)['blocked_users'] as List<dynamic>;
      return userIds.cast<String>();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// 特定のユーザーがブロックされているか確認
  Future<bool> isUserBlocked(String userId) async {
    final blockedUsers = await getBlockedUsers();
    return blockedUsers.contains(userId);
  }
}

/// API例外
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  factory ApiException.fromDioError(DioException error) {
    if (error.response != null) {
      final data = error.response!.data;
      String message = 'エラーが発生しました';

      if (data is Map<String, dynamic>) {
        message = data['message'] as String? ??
            data['error'] as String? ??
            message;
      }

      return ApiException(message, error.response!.statusCode);
    }

    return ApiException('ネットワークエラーが発生しました');
  }

  @override
  String toString() => message;
}
