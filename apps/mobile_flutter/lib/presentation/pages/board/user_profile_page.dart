import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/auth/secure_token_storage.dart';
import '../../../data/models/board_models.dart';
import '../../../data/models/meal_models.dart';
import '../../../data/models/subscription_models.dart';
import '../subscription/blocked_users_page.dart';

/// ユーザープロフィールページ（完全版：SNSリンク、ブロック機能、オンライン状態、食事制限）
class UserProfilePage extends ConsumerStatefulWidget {
  final String userId;
  final String displayName;
  final String? avatarUrl;

  const UserProfilePage({
    super.key,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });

  @override
  ConsumerState<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends ConsumerState<UserProfilePage> {
  bool _loading = true;
  String? _error;
  WorkoutDatesWithVolume? _workoutData;
  List<MealEntry> _todayMeals = [];
  List<SnsLink> _snsLinks = [];
  bool _isSelf = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ローカルストレージから直接自分のIDを取得（APIに依存しない）
      final myUserId = await SecureTokenStorage.getUserId();
      _isSelf = myUserId == widget.userId;

      // デバッグログ
      if (kDebugMode) {
        print('[UserProfilePage] myUserId: $myUserId, widget.userId: ${widget.userId}, _isSelf: $_isSelf');
      }

      final boardService = ref.read(boardServiceProvider);
      final subscriptionService = ref.read(subscriptionServiceProvider);

      // ワークアウト履歴は常に取得
      final workoutData = await boardService.getUserWorkoutDates(widget.userId);

      // 食事メニューとSNSリンクを取得（エラーは無視してトレーニング履歴は表示する）
      List<MealEntry> meals = [];
      List<SnsLink> snsLinks = [];

      try {
        meals = await boardService.getUserMealsToday(widget.userId);
      } catch (e) {
        // エラーは無視（403/404などサブスク制限やAPI未実装）
        if (kDebugMode) {
          print('[UserProfilePage] meals error: $e');
        }
      }

      try {
        snsLinks = await subscriptionService.getUserSnsLinks(widget.userId);
      } catch (e) {
        // エラーは無視（403/404などサブスク制限やAPI未実装）
        if (kDebugMode) {
          print('[UserProfilePage] snsLinks error: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _workoutData = workoutData;
        _todayMeals = meals;
        _snsLinks = snsLinks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.textSecondary),
          ),
          const Spacer(),
          if (!_isSelf) ...[
            // ブロックボタン（Premium機能）
            _buildBlockButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildBlockButton() {
    return Consumer(
      builder: (context, ref, _) {
        final tierAsync = ref.watch(subscriptionTierProvider);
        final tier = tierAsync.valueOrNull ?? SubscriptionTier.free;
        final canBlock = tier == SubscriptionTier.premium;

        return IconButton(
          onPressed: canBlock
              ? () => showBlockUserDialog(context, ref, widget.userId, widget.displayName)
              : () => _showPremiumRequired(context, 'ブロック機能'),
          icon: Icon(
            Icons.block,
            color: canBlock ? AppColors.error : AppColors.textTertiary,
          ),
          tooltip: canBlock ? 'ブロック' : 'プレミアムプラン限定',
        );
      },
    );
  }

  void _showPremiumRequired(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('プレミアムプラン限定', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          '$featureName を使用するにはプレミアムプランが必要です。',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            child: const Text('アップグレード', style: TextStyle(color: AppColors.greenPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _buildAvatar(widget.avatarUrl, widget.displayName),
          const SizedBox(height: 16),
          // 名前とプレミアム誘導アイコン
          _buildNameWithInfoIcon(),
          const SizedBox(height: 8),
          // オンライン状態表示（Premium機能）
          _buildOnlineStatus(),
          const SizedBox(height: 32),
          // SNSリンク（Basic以上）
          _buildSnsLinksSection(),
          const SizedBox(height: 24),
          // トレーニング履歴
          _buildWorkoutSection(),
          const SizedBox(height: 24),
          // 今日の食事（Basic以上）
          _buildTodayMealsSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 名前とプレミアム誘導のiアイコンを表示
  Widget _buildNameWithInfoIcon() {
    return Consumer(
      builder: (context, ref, _) {
        final tierAsync = ref.watch(subscriptionTierProvider);
        final tier = tierAsync.valueOrNull ?? SubscriptionTier.free;
        final isPremium = tier == SubscriptionTier.premium;

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.displayName,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            // Premiumユーザーにはiアイコンを表示しない
            if (!isPremium) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _showOnlineStatusPremiumInfo(context),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.textTertiary.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      'i',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// ログイン状態を見るにはプレミアムが必要という情報ダイアログ
  void _showOnlineStatusPremiumInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Row(
          children: [
            Icon(Icons.workspace_premium, color: Colors.amber[600], size: 24),
            const SizedBox(width: 8),
            const Text(
              'プレミアム機能',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: const Text(
          'このユーザーのログイン状態（オンライン/オフライン）を確認するには、プレミアムプランへのアップグレードが必要です。',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる', style: TextStyle(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            child: Text(
              'プランを見る',
              style: TextStyle(color: Colors.amber[600], fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineStatus() {
    return Consumer(
      builder: (context, ref, _) {
        final tierAsync = ref.watch(subscriptionTierProvider);
        final tier = tierAsync.valueOrNull ?? SubscriptionTier.free;

        // Premiumユーザーのみオンライン状態を表示
        if (tier != SubscriptionTier.premium) {
          return const SizedBox.shrink();
        }

        // TODO: 実際のオンライン状態をバックエンドから取得
        // 今はプレースホルダーとして「オフライン」を表示
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.textTertiary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'オフライン',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSnsLinksSection() {
    return Consumer(
      builder: (context, ref, _) {
        final tierAsync = ref.watch(subscriptionTierProvider);
        final tier = tierAsync.valueOrNull ?? SubscriptionTier.free;
        final hasAccess = tier == SubscriptionTier.basic || tier == SubscriptionTier.premium;

        // アクセス権があってSNSリンクがない場合は非表示
        if (hasAccess && _snsLinks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            children: [
              // SNSリンクコンテンツ
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.link, color: AppColors.greenPrimary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'SNSリンク',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (hasAccess)
                      ..._snsLinks.map((link) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(_getSnsIcon(link.type), size: 18, color: AppColors.textSecondary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    link.url,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.greenPrimary,
                                      decoration: TextDecoration.underline,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ))
                    else
                      // 無料ユーザー向けダミーコンテンツ
                      _buildMockSnsLinks(),
                  ],
                ),
              ),
              // 無料ユーザーにはモザイクオーバーレイ
              if (!hasAccess)
                Positioned.fill(
                  child: _buildSnsBlurOverlay(context),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMockSnsLinks() {
    return Column(
      children: [
        _buildMockSnsLinkItem(Icons.cancel, '@username_xxx'),
        _buildMockSnsLinkItem(Icons.photo_camera, 'instagram.com/xxxxx'),
      ],
    );
  }

  Widget _buildMockSnsLinkItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.greenPrimary,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSnsBlurOverlay(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          color: AppColors.bgCard.withOpacity(0.6),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  color: AppColors.greenPrimary,
                  size: 24,
                ),
                const SizedBox(height: 8),
                const Text(
                  'SNSリンクを見るには',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const Text(
                  'ベーシックプラン以上が必要です',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => context.push('/subscription'),
                  child: const Text(
                    'プランを見る',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.greenPrimary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getSnsIcon(String type) {
    switch (type.toLowerCase()) {
      case 'twitter':
      case 'x':
        return Icons.cancel; // Use a generic icon
      case 'instagram':
        return Icons.photo_camera;
      case 'youtube':
        return Icons.play_circle;
      case 'tiktok':
        return Icons.music_note;
      default:
        return Icons.link;
    }
  }

  Widget _buildWorkoutSection() {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.greenPrimary),
        ),
      );
    }

    if (_error != null || _workoutData == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: AppColors.textTertiary),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadData,
              child: const Text('再読み込み'),
            ),
          ],
        ),
      );
    }

    return _TrainingGrass(workoutData: _workoutData!);
  }

  Widget _buildTodayMealsSection() {
    if (_loading) {
      return const SizedBox.shrink();
    }

    return Consumer(
      builder: (context, ref, _) {
        final tierAsync = ref.watch(subscriptionTierProvider);
        final tier = tierAsync.valueOrNull ?? SubscriptionTier.free;
        final hasAccess = tier == SubscriptionTier.basic || tier == SubscriptionTier.premium;

        return Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Stack(
            children: [
              // 食事コンテンツ
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.restaurant_outlined, color: AppColors.greenPrimary, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          '今日の食事',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (_todayMeals.isNotEmpty && hasAccess)
                          Text(
                            '${_todayMeals.fold(0, (sum, m) => sum + m.totalCalories)} kcal',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_todayMeals.isEmpty && hasAccess)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            '今日の食事はまだ記録されていません',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      )
                    else if (hasAccess)
                      ..._todayMeals.map((meal) => _buildMealItem(meal))
                    else
                      // 無料ユーザー向けダミーコンテンツ（モザイクで隠す）
                      _buildMockMealContent(),
                  ],
                ),
              ),
              // 無料ユーザーにはモザイクオーバーレイ
              if (!hasAccess)
                Positioned.fill(
                  child: _buildMealBlurOverlay(context),
                ),
            ],
          ),
        );
      },
    );
  }

  /// モザイク用のダミー食事コンテンツ
  Widget _buildMockMealContent() {
    return Column(
      children: [
        _buildMockMealItem('朝食', '08:00', ['オートミール', 'バナナ', 'プロテイン']),
        const SizedBox(height: 8),
        _buildMockMealItem('昼食', '12:30', ['鶏胸肉', '玄米', 'サラダ']),
      ],
    );
  }

  Widget _buildMockMealItem(String type, String time, List<String> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgMain,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                type,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.greenPrimary,
                ),
              ),
              const Spacer(),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '$item (???kcal)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  /// 食事セクションのブラーオーバーレイ
  Widget _buildMealBlurOverlay(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          color: AppColors.bgCard.withOpacity(0.6),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.greenPrimary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: AppColors.greenPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '食事メニューを見るには',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'ベーシックプラン以上が必要です',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.push('/subscription'),
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.greenPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'プランを見る',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMealItem(MealEntry meal) {
    final timeStr = DateFormat('HH:mm').format(meal.time);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bgMain,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                meal.type.displayName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.greenPrimary,
                ),
              ),
              const Spacer(),
              Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...meal.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${item.name} (${item.calories}kcal)',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String displayName) {
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarUrl,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialAvatar(initial),
        ),
      );
    }
    return _buildInitialAvatar(initial);
  }

  Widget _buildInitialAvatar(String initial) {
    return Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(
        color: AppColors.greenPrimary,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// トレーニンググラス（ワークアウト履歴の可視化）- muscleページと同じデザイン
class _TrainingGrass extends StatelessWidget {
  final WorkoutDatesWithVolume workoutData;

  const _TrainingGrass({required this.workoutData});

  static const int _weeksToShow = 16;
  static const int _daysInWeek = 7;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // 今週の日曜日を取得（週の開始）
    final currentWeekStart = todayDate.subtract(Duration(days: todayDate.weekday % 7));

    // 16週間前の日曜日
    final startDate = currentWeekStart.subtract(const Duration(days: (_weeksToShow - 1) * 7));

    final scoreMap = _computeScoreMap();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ヘッダー
          Row(
            children: [
              const Text(
                'ワークアウト記録',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${workoutData.workouts.length}回',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 月ラベル
          _buildMonthLabels(startDate),
          const SizedBox(height: 4),
          // グラフ本体
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 曜日ラベル
              _buildDayLabels(),
              const SizedBox(width: 4),
              // グリッド
              Expanded(
                child: _buildGrid(startDate, scoreMap, todayDate),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 凡例
          _buildLegend(),
        ],
      ),
    );
  }

  /// スコアマップを計算
  Map<DateTime, double> _computeScoreMap() {
    final scoreMap = <DateTime, double>{};
    for (final workout in workoutData.workouts) {
      final dateParts = workout.date.split('-');
      if (dateParts.length == 3) {
        final dateKey = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );
        // volumeがあればそれを使う、なければ1
        scoreMap[dateKey] = (scoreMap[dateKey] ?? 0) + (workout.volume ?? 100);
      }
    }
    return scoreMap;
  }

  /// 月ラベル
  Widget _buildMonthLabels(DateTime startDate) {
    final months = <String>[];
    final positions = <int>[];
    String? lastMonth;

    for (int week = 0; week < _weeksToShow; week++) {
      final weekStart = startDate.add(Duration(days: week * 7));
      final monthName = _getMonthName(weekStart.month);
      if (monthName != lastMonth) {
        months.add(monthName);
        positions.add(week);
        lastMonth = monthName;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: SizedBox(
        height: 14,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cellWidth = constraints.maxWidth / _weeksToShow;
            return Stack(
              children: [
                for (int i = 0; i < months.length; i++)
                  Positioned(
                    left: positions[i] * cellWidth,
                    child: Text(
                      months[i],
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 曜日ラベル
  Widget _buildDayLabels() {
    const days = ['', '月', '', '水', '', '金', ''];
    return Column(
      children: days.map((day) => SizedBox(
        height: 13,
        width: 16,
        child: Text(
          day,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
          ),
        ),
      )).toList(),
    );
  }

  /// グリッド本体
  Widget _buildGrid(
    DateTime startDate,
    Map<DateTime, double> scoreMap,
    DateTime today,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize = (constraints.maxWidth / _weeksToShow) - 2;
        final actualCellSize = cellSize.clamp(8.0, 13.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(_weeksToShow, (weekIndex) {
            return Column(
              children: List.generate(_daysInWeek, (dayIndex) {
                final date = startDate.add(Duration(days: weekIndex * 7 + dayIndex));
                final score = scoreMap[date] ?? 0;
                final isFuture = date.isAfter(today);

                return Container(
                  width: actualCellSize,
                  height: actualCellSize,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color: isFuture
                        ? Colors.transparent
                        : _getColorByScore(score),
                    borderRadius: BorderRadius.circular(2),
                    border: isFuture
                        ? Border.all(color: AppColors.border.withOpacity(0.3), width: 0.5)
                        : null,
                  ),
                );
              }),
            );
          }),
        );
      },
    );
  }

  /// スコアに基づいて色を取得
  Color _getColorByScore(double score) {
    if (score <= 0) {
      return AppColors.bgSub;  // トレーニングなし
    } else if (score < 80) {
      return const Color(0xFF0E4429);  // 薄い緑
    } else if (score < 120) {
      return const Color(0xFF006D32);  // 中間の緑
    } else if (score < 160) {
      return const Color(0xFF26A641);  // 濃い緑
    } else {
      return const Color(0xFF39D353);  // 最も濃い緑
    }
  }

  /// 凡例
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          'Less',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(width: 4),
        _buildLegendCell(AppColors.bgSub),
        _buildLegendCell(const Color(0xFF0E4429)),
        _buildLegendCell(const Color(0xFF006D32)),
        _buildLegendCell(const Color(0xFF26A641)),
        _buildLegendCell(const Color(0xFF39D353)),
        const SizedBox(width: 4),
        const Text(
          'More',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w500,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendCell(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['1月', '2月', '3月', '4月', '5月', '6月',
                    '7月', '8月', '9月', '10月', '11月', '12月'];
    return months[month - 1];
  }
}
