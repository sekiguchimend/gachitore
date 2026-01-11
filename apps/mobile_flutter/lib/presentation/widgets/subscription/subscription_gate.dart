import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/subscription_models.dart';

/// サブスクリプション必須機能のゲートウィジェット
/// 必要なティアに達していない場合、アップグレードダイアログを表示
class SubscriptionGate extends ConsumerWidget {
  final SubscriptionTier requiredTier;
  final Widget child;
  final String featureName;

  const SubscriptionGate({
    super.key,
    required this.requiredTier,
    required this.child,
    required this.featureName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(subscriptionTierProvider);

    return tierAsync.when(
      data: (currentTier) {
        if (_hasAccess(currentTier)) {
          return child;
        } else {
          return _buildLockedContent(context);
        }
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => _buildLockedContent(context),
    );
  }

  bool _hasAccess(SubscriptionTier currentTier) {
    if (requiredTier == SubscriptionTier.free) return true;
    if (requiredTier == SubscriptionTier.basic) {
      return currentTier == SubscriptionTier.basic ||
          currentTier == SubscriptionTier.premium;
    }
    if (requiredTier == SubscriptionTier.premium) {
      return currentTier == SubscriptionTier.premium;
    }
    return false;
  }

  Widget _buildLockedContent(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              '$featureName は ${requiredTier.displayName} プラン限定です',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'この機能を利用するには、${requiredTier.displayName} プランにアップグレードしてください',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                context.push('/subscription');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'プランを見る',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 機能ボタンにサブスクリプション必須マークを追加するウィジェット
class SubscriptionRequiredBadge extends ConsumerWidget {
  final SubscriptionTier requiredTier;
  final Widget child;
  final VoidCallback onTap;

  const SubscriptionRequiredBadge({
    super.key,
    required this.requiredTier,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(subscriptionTierProvider);

    return tierAsync.when(
      data: (currentTier) {
        final hasAccess = _hasAccess(currentTier);

        return GestureDetector(
          onTap: hasAccess
              ? onTap
              : () => _showUpgradeDialog(context, currentTier),
          child: Stack(
            children: [
              Opacity(
                opacity: hasAccess ? 1.0 : 0.5,
                child: child,
              ),
              if (!hasAccess)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.star,
                      size: 14,
                      color: Colors.black,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => child,
      error: (_, __) => child,
    );
  }

  bool _hasAccess(SubscriptionTier currentTier) {
    if (requiredTier == SubscriptionTier.free) return true;
    if (requiredTier == SubscriptionTier.basic) {
      return currentTier == SubscriptionTier.basic ||
          currentTier == SubscriptionTier.premium;
    }
    if (requiredTier == SubscriptionTier.premium) {
      return currentTier == SubscriptionTier.premium;
    }
    return false;
  }

  void _showUpgradeDialog(BuildContext context, SubscriptionTier currentTier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Row(
          children: [
            const Icon(Icons.star, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              '${requiredTier.displayName} 限定機能',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'この機能を利用するには、${requiredTier.displayName} プランにアップグレードしてください。',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            child: const Text('プランを見る'),
          ),
        ],
      ),
    );
  }
}

/// 関数ベースのサブスクリプションチェック
Future<bool> checkSubscriptionAccess(
  BuildContext context,
  WidgetRef ref,
  SubscriptionTier requiredTier,
  String featureName,
) async {
  final tierAsync = ref.read(subscriptionTierProvider);

  return tierAsync.when(
    data: (currentTier) {
      final hasAccess = _checkAccess(currentTier, requiredTier);

      if (!hasAccess) {
        _showUpgradeBottomSheet(context, requiredTier, featureName);
      }

      return hasAccess;
    },
    loading: () => false,
    error: (_, __) => false,
  );
}

bool _checkAccess(SubscriptionTier current, SubscriptionTier required) {
  if (required == SubscriptionTier.free) return true;
  if (required == SubscriptionTier.basic) {
    return current == SubscriptionTier.basic || current == SubscriptionTier.premium;
  }
  if (required == SubscriptionTier.premium) {
    return current == SubscriptionTier.premium;
  }
  return false;
}

void _showUpgradeBottomSheet(
  BuildContext context,
  SubscriptionTier requiredTier,
  String featureName,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, size: 48, color: Colors.amber),
          const SizedBox(height: 16),
          Text(
            '${requiredTier.displayName} 限定機能',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$featureName は ${requiredTier.displayName} プラン限定です',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/subscription');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                '${requiredTier.displayName} プランを見る',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    ),
  );
}
