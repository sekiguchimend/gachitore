import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/meal_models.dart';

/// ユーザープロフィールページ
///
/// N+1問題を回避するため:
/// - displayName, avatarUrl は投稿データから渡される（再取得しない）
/// - workoutDates のみを追加で取得する
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
  List<String> _workoutDates = [];
  List<MealEntry> _todayMeals = [];

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
      final boardService = ref.read(boardServiceProvider);
      // ワークアウト履歴と今日の食事を並列で取得
      final results = await Future.wait([
        boardService.getUserWorkoutDates(widget.userId),
        boardService.getUserMealsToday(widget.userId),
      ]);
      if (!mounted) return;
      setState(() {
        _workoutDates = results[0] as List<String>;
        _todayMeals = results[1] as List<MealEntry>;
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
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 0,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const Center(
              child: Text(
                'プロフィール',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    // displayName と avatarUrl は widget から取得（N+1回避）
    final displayName = widget.displayName;
    final avatarUrl = widget.avatarUrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Avatar（渡されたデータを使用）
          _buildAvatar(avatarUrl, displayName),
          const SizedBox(height: 16),
          // Name（渡されたデータを使用）
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          // Training grass（追加で取得）
          _buildWorkoutSection(),
          const SizedBox(height: 24),
          // Today's meals
          _buildTodayMealsSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
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

    if (_error != null) {
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

    return _TrainingGrass(workoutDates: _workoutDates);
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
      decoration: BoxDecoration(
        color: AppColors.greenPrimary.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w700,
            color: AppColors.greenPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildTodayMealsSection() {
    if (_loading) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.restaurant_outlined,
                color: AppColors.greenPrimary,
                size: 20,
              ),
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
              if (_todayMeals.isNotEmpty)
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
          if (_todayMeals.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Icon(
                      Icons.restaurant_outlined,
                      size: 32,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'まだ記録されていません',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._todayMeals.map((meal) => _buildMealCard(meal)),
        ],
      ),
    );
  }

  Widget _buildMealCard(MealEntry meal) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgSub,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _getMealColor(meal.type).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getMealIcon(meal.type),
              color: _getMealColor(meal.type),
              size: 18,
            ),
          ),
          title: Text(
            meal.type.displayName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            '${meal.totalCalories} kcal • P ${meal.totalProtein.round()}g',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          trailing: Text(
            '${meal.time.hour}:${meal.time.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          children: [
            ...meal.items.map((item) => _buildMealItemRow(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildMealItemRow(MealItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '${item.calories} kcal',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMealIcon(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return Icons.wb_sunny_outlined;
      case MealType.lunch:
        return Icons.wb_cloudy_outlined;
      case MealType.dinner:
        return Icons.nights_stay_outlined;
      default:
        return Icons.cookie_outlined;
    }
  }

  Color _getMealColor(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return AppColors.warning;
      case MealType.lunch:
        return AppColors.greenPrimary;
      case MealType.dinner:
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }
}

/// GitHub風のトレーニング履歴草グラフ
class _TrainingGrass extends StatelessWidget {
  final List<String> workoutDates;

  const _TrainingGrass({required this.workoutDates});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final workoutSet = workoutDates.toSet();

    // 過去12週間 (84日) を表示
    const weeksToShow = 12;
    const daysInWeek = 7;

    // 開始日を計算 (今日から weeksToShow 週間前の日曜日)
    final daysFromSunday = today.weekday % 7;
    final startDate = today.subtract(Duration(days: (weeksToShow * daysInWeek) + daysFromSunday - 1));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fitness_center,
                color: AppColors.greenPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'トレーニング履歴',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${workoutDates.length}回',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 月ラベル
          _buildMonthLabels(startDate, weeksToShow),
          const SizedBox(height: 4),
          // 草グラフ
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 曜日ラベル
              _buildWeekdayLabels(),
              const SizedBox(width: 4),
              // グラフ本体
              Expanded(
                child: _buildGrassGrid(startDate, weeksToShow, daysInWeek, today, workoutSet),
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

  Widget _buildMonthLabels(DateTime startDate, int weeksToShow) {
    int? lastMonth;
    final months = <Widget>[];

    for (int week = 0; week < weeksToShow; week++) {
      final weekStart = startDate.add(Duration(days: week * 7));
      if (weekStart.month != lastMonth) {
        months.add(
          SizedBox(
            width: 14,
            child: Text(
              DateFormat('M').format(weekStart),
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        );
        lastMonth = weekStart.month;
      } else {
        months.add(const SizedBox(width: 14));
      }
    }

    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Row(children: months),
    );
  }

  Widget _buildWeekdayLabels() {
    const labels = ['', '月', '', '水', '', '金', ''];
    return Column(
      children: labels.map((label) {
        return SizedBox(
          height: 14,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.textTertiary,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGrassGrid(
    DateTime startDate,
    int weeksToShow,
    int daysInWeek,
    DateTime today,
    Set<String> workoutSet,
  ) {
    return Row(
      children: List.generate(weeksToShow, (weekIndex) {
        return Column(
          children: List.generate(daysInWeek, (dayIndex) {
            final date = startDate.add(Duration(days: weekIndex * 7 + dayIndex));
            final dateStr = DateFormat('yyyy-MM-dd').format(date);
            final hasWorkout = workoutSet.contains(dateStr);
            final isFuture = date.isAfter(today);

            return Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: isFuture
                    ? Colors.transparent
                    : hasWorkout
                        ? AppColors.greenPrimary
                        : AppColors.bgSub,
                borderRadius: BorderRadius.circular(2),
                border: isFuture
                    ? Border.all(color: AppColors.border.withOpacity(0.3))
                    : null,
              ),
            );
          }),
        );
      }),
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          '少',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.bgSub,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.greenPrimary.withOpacity(0.5),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 2),
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: AppColors.greenPrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        const Text(
          '多',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}
