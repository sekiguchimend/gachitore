/// Subscription models for IAP (In-App Purchase)
/// Supports Basic (¥1,000/month) and Premium (¥3,000/month) tiers

enum SubscriptionTier {
  free,
  basic,
  premium;

  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return '無料';
      case SubscriptionTier.basic:
        return 'ベーシック';
      case SubscriptionTier.premium:
        return 'プレミアム';
    }
  }

  String get price {
    switch (this) {
      case SubscriptionTier.free:
        return '¥0';
      case SubscriptionTier.basic:
        return '¥1,000/月';
      case SubscriptionTier.premium:
        return '¥3,000/月';
    }
  }

  static SubscriptionTier fromString(String value) {
    switch (value.toLowerCase()) {
      case 'basic':
        return SubscriptionTier.basic;
      case 'premium':
        return SubscriptionTier.premium;
      default:
        return SubscriptionTier.free;
    }
  }
}

class UserSubscription {
  final String id;
  final String userId;
  final SubscriptionTier tier;
  final String platform;
  final String productId;
  final String? purchaseToken;
  final String? transactionId;
  final DateTime startsAt;
  final DateTime expiresAt;
  final bool autoRenewing;
  final SubscriptionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSubscription({
    required this.id,
    required this.userId,
    required this.tier,
    required this.platform,
    required this.productId,
    this.purchaseToken,
    this.transactionId,
    required this.startsAt,
    required this.expiresAt,
    required this.autoRenewing,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tier: SubscriptionTier.fromString(json['subscription_tier'] as String),
      platform: json['platform'] as String,
      productId: json['product_id'] as String,
      purchaseToken: json['purchase_token'] as String?,
      transactionId: json['transaction_id'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      autoRenewing: json['auto_renewing'] as bool,
      status: SubscriptionStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'subscription_tier': tier.name,
      'platform': platform,
      'product_id': productId,
      'purchase_token': purchaseToken,
      'transaction_id': transactionId,
      'starts_at': startsAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'auto_renewing': autoRenewing,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isActive {
    return status == SubscriptionStatus.active &&
        expiresAt.isAfter(DateTime.now());
  }

  bool get hasBasicOrHigher {
    return isActive && (tier == SubscriptionTier.basic || tier == SubscriptionTier.premium);
  }

  bool get hasPremium {
    return isActive && tier == SubscriptionTier.premium;
  }
}

enum SubscriptionStatus {
  active,
  cancelled,
  expired,
  pending;

  static SubscriptionStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'active':
        return SubscriptionStatus.active;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'expired':
        return SubscriptionStatus.expired;
      case 'pending':
        return SubscriptionStatus.pending;
      default:
        return SubscriptionStatus.expired;
    }
  }
}

class SnsLink {
  final String type;
  final String url;

  SnsLink({
    required this.type,
    required this.url,
  });

  factory SnsLink.fromJson(Map<String, dynamic> json) {
    return SnsLink(
      type: json['type'] as String,
      url: json['url'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'url': url,
    };
  }
}

class UserBlock {
  final String id;
  final String blockerUserId;
  final String blockedUserId;
  final DateTime createdAt;

  UserBlock({
    required this.id,
    required this.blockerUserId,
    required this.blockedUserId,
    required this.createdAt,
  });

  factory UserBlock.fromJson(Map<String, dynamic> json) {
    return UserBlock(
      id: json['id'] as String,
      blockerUserId: json['blocker_user_id'] as String,
      blockedUserId: json['blocked_user_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'blocker_user_id': blockerUserId,
      'blocked_user_id': blockedUserId,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Product IDs for Google Play Store
class SubscriptionProducts {
  static const String basicMonthly = 'gachitore_basic_monthly';
  static const String premiumMonthly = 'gachitore_premium_monthly';

  static List<String> get allProductIds => [basicMonthly, premiumMonthly];

  static SubscriptionTier tierFromProductId(String productId) {
    switch (productId) {
      case basicMonthly:
        return SubscriptionTier.basic;
      case premiumMonthly:
        return SubscriptionTier.premium;
      default:
        return SubscriptionTier.free;
    }
  }

  static String productIdFromTier(SubscriptionTier tier) {
    switch (tier) {
      case SubscriptionTier.basic:
        return basicMonthly;
      case SubscriptionTier.premium:
        return premiumMonthly;
      case SubscriptionTier.free:
        return '';
    }
  }
}

/// Subscription feature descriptions
class SubscriptionFeatures {
  static const List<String> freeFeatures = [
    '基本的なトレーニング記録',
    '食事記録',
    'AIアドバイス',
    '掲示板閲覧・投稿',
  ];

  static const List<String> basicFeatures = [
    ...freeFeatures,
    'プロフィールにSNSリンク表示',
    '他のユーザーの食事メニュー閲覧',
  ];

  static const List<String> premiumFeatures = [
    ...basicFeatures,
    'ユーザーのオンライン状態表示',
    '特定ユーザーのブロック機能',
  ];
}
