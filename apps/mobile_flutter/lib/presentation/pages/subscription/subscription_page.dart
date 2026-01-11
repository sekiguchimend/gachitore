import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'dart:async';
import '../../../core/providers/providers.dart';
import '../../../data/models/subscription_models.dart';

/// サブスクリプション管理ページ
class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  List<ProductDetails>? _products;
  bool _isLoading = true;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _listenToPurchases();
  }

  @override
  void dispose() {
    _purchaseSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final iapService = ref.read(iapServiceProvider);
      final isAvailable = await iapService.isAvailable();

      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('アプリ内課金が利用できません')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final products = await iapService.getProducts();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('商品情報の取得に失敗しました: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _listenToPurchases() {
    final iapService = ref.read(iapServiceProvider);
    _purchaseSubscription = iapService.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          if (purchase.status == PurchaseStatus.purchased) {
            await _verifyAndCompletePurchase(purchase);
          } else if (purchase.status == PurchaseStatus.error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('購入に失敗しました: ${purchase.error?.message ?? "不明なエラー"}'),
                ),
              );
            }
            await iapService.completePurchase(purchase);
          }
        }
      },
    );
  }

  Future<void> _verifyAndCompletePurchase(PurchaseDetails purchase) async {
    try {
      final iapService = ref.read(iapServiceProvider);
      final subscriptionService = ref.read(subscriptionServiceProvider);

      // Get purchase token (Android only)
      final purchaseToken = iapService.getPurchaseToken(purchase);
      final transactionId = iapService.getOrderId(purchase);

      if (purchaseToken == null) {
        throw Exception('購入トークンを取得できませんでした');
      }

      // Verify with backend
      await subscriptionService.verifyPurchase(
        platform: 'android',
        productId: purchase.productID,
        purchaseToken: purchaseToken,
        transactionId: transactionId,
      );

      // Complete purchase
      await iapService.completePurchase(purchase);

      // Refresh subscription state
      ref.invalidate(currentSubscriptionProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('購入が完了しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('購入の検証に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _handlePurchase(ProductDetails product) async {
    final iapService = ref.read(iapServiceProvider);
    final success = await iapService.purchase(product);

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('購入を開始できませんでした')),
      );
    }
  }

  Future<void> _handleRestore() async {
    try {
      final iapService = ref.read(iapServiceProvider);
      await iapService.restorePurchases();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('購入を復元しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('復元に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _handleCancel() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('サブスクリプションをキャンセル'),
        content: const Text(
          '本当にキャンセルしますか？\n現在の期間が終了するまでは引き続き機能をご利用いただけます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('戻る'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('キャンセル'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final subscriptionService = ref.read(subscriptionServiceProvider);
      await subscriptionService.cancelSubscription();
      ref.invalidate(currentSubscriptionProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('サブスクリプションをキャンセルしました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('キャンセルに失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionAsync = ref.watch(currentSubscriptionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF323232),
      appBar: AppBar(
        title: const Text('プレミアムプラン', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: subscriptionAsync.when(
        data: (subscription) => _buildContent(subscription),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }

  Widget _buildContent(UserSubscription? subscription) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current status
            if (subscription != null && subscription.isActive) ...[
              _buildCurrentPlanCard(subscription),
              const SizedBox(height: 24),
            ],

            // Plan cards
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_products != null && _products!.isNotEmpty) ...[
              const Text(
                'プランを選択',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildPlanCard(
                tier: SubscriptionTier.basic,
                product: _products!.firstWhere(
                  (p) => p.id == SubscriptionProducts.basicMonthly,
                  orElse: () => _products!.first,
                ),
                currentTier: subscription?.tier ?? SubscriptionTier.free,
              ),
              const SizedBox(height: 16),
              _buildPlanCard(
                tier: SubscriptionTier.premium,
                product: _products!.firstWhere(
                  (p) => p.id == SubscriptionProducts.premiumMonthly,
                  orElse: () => _products!.last,
                ),
                currentTier: subscription?.tier ?? SubscriptionTier.free,
              ),
            ] else ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    '商品情報を取得できませんでした',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Restore button
            Center(
              child: TextButton(
                onPressed: _handleRestore,
                child: const Text(
                  '購入を復元',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Cancel button (if subscribed)
            if (subscription != null && subscription.isActive && subscription.autoRenewing)
              Center(
                child: TextButton(
                  onPressed: _handleCancel,
                  child: const Text(
                    'サブスクリプションをキャンセル',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPlanCard(UserSubscription subscription) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                '現在のプラン: ${subscription.tier.displayName}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '有効期限: ${_formatDate(subscription.expiresAt)}',
            style: const TextStyle(color: Colors.white70),
          ),
          if (!subscription.autoRenewing)
            const Text(
              '自動更新: オフ',
              style: TextStyle(color: Colors.orange),
            ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required SubscriptionTier tier,
    required ProductDetails product,
    required SubscriptionTier currentTier,
  }) {
    final isCurrentPlan = tier == currentTier;
    final features = tier == SubscriptionTier.basic
        ? SubscriptionFeatures.basicFeatures
        : SubscriptionFeatures.premiumFeatures;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isCurrentPlan ? const Color(0xFF1E1E1E) : Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentPlan ? Colors.white : Colors.white24,
          width: isCurrentPlan ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tier.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.price,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (isCurrentPlan)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    '現在のプラン',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCurrentPlan ? null : () => _handlePurchase(product),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrentPlan ? Colors.grey : Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                isCurrentPlan ? '契約中' : '購入する',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}
