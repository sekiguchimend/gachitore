import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import '../models/subscription_models.dart';

/// In-App Purchase サービス（Google Play Store）
class IapService {
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// WebではIAP非対応、Android/iOSのみ
  bool get _isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
       defaultTargetPlatform == TargetPlatform.iOS);

  /// IAPが利用可能か確認
  Future<bool> isAvailable() async {
    if (!_isSupportedPlatform) return false;
    return await InAppPurchase.instance.isAvailable();
  }

  /// 商品情報を取得
  Future<List<ProductDetails>> getProducts() async {
    if (!_isSupportedPlatform) return const [];

    final productIds = SubscriptionProducts.allProductIds.toSet();
    final response = await InAppPurchase.instance.queryProductDetails(productIds);

    if (response.notFoundIDs.isNotEmpty) {
      debugPrint('商品が見つかりません: ${response.notFoundIDs}');
    }

    return response.productDetails;
  }

  /// 購入を開始
  Future<bool> purchase(ProductDetails product) async {
    if (!_isSupportedPlatform) return false;
    final purchaseParam = PurchaseParam(productDetails: product);
    return await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
  }

  /// 購入イベントをリッスン
  Stream<List<PurchaseDetails>> get purchaseStream {
    if (!_isSupportedPlatform) return const Stream.empty();
    return InAppPurchase.instance.purchaseStream;
  }

  /// 購入を完了（確認済み後に呼ぶ）
  Future<void> completePurchase(PurchaseDetails purchase) async {
    if (!_isSupportedPlatform) return;
    await InAppPurchase.instance.completePurchase(purchase);
  }

  /// 過去の購入を復元
  Future<void> restorePurchases() async {
    if (!_isSupportedPlatform) return;
    await InAppPurchase.instance.restorePurchases();
  }

  /// Android の購入トークンを取得
  String? getPurchaseToken(PurchaseDetails purchase) {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (isAndroid && purchase is GooglePlayPurchaseDetails) {
      return purchase.billingClientPurchase.purchaseToken;
    }
    return null;
  }

  /// Android の order ID を取得
  String? getOrderId(PurchaseDetails purchase) {
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    if (isAndroid && purchase is GooglePlayPurchaseDetails) {
      return purchase.billingClientPurchase.orderId;
    }
    return null;
  }

  /// 購入が pending 状態か確認
  bool isPending(PurchaseDetails purchase) {
    return purchase.status == PurchaseStatus.pending;
  }

  /// 購入が完了したか確認
  bool isPurchased(PurchaseDetails purchase) {
    return purchase.status == PurchaseStatus.purchased;
  }

  /// 購入がエラーか確認
  bool isError(PurchaseDetails purchase) {
    return purchase.status == PurchaseStatus.error;
  }

  /// エラーメッセージを取得
  String? getErrorMessage(PurchaseDetails purchase) {
    return purchase.error?.message;
  }

  /// クリーンアップ
  void dispose() {
    _subscription?.cancel();
  }
}
