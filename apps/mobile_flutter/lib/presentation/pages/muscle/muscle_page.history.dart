part of 'muscle_page.dart';

extension _MusclePageHistory on _MusclePageState {
  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.greenPrimary,
        ),
      );
    }

    if (_recentWorkouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            const Text(
              'ワークアウト履歴がありません',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // 日付ごとにグループ化
    final groupedWorkouts = _groupWorkoutsByDate(_recentWorkouts);

    return RefreshIndicator(
      onRefresh: _loadWorkoutHistory,
      color: AppColors.greenPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedWorkouts.length,
        itemBuilder: (context, index) {
          final entry = groupedWorkouts.entries.elementAt(index);
          return _buildDaySection(entry.key, entry.value);
        },
      ),
    );
  }

  /// ワークアウトを日付でグループ化
  Map<DateTime, List<WorkoutSession>> _groupWorkoutsByDate(
      List<WorkoutSession> workouts) {
    final Map<DateTime, List<WorkoutSession>> grouped = {};

    for (final workout in workouts) {
      final dateKey = DateTime(
        workout.date.year,
        workout.date.month,
        workout.date.day,
      );

      if (grouped.containsKey(dateKey)) {
        grouped[dateKey]!.add(workout);
      } else {
        grouped[dateKey] = [workout];
      }
    }

    // 日付で降順ソート
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Map.fromEntries(
      sortedKeys.map((key) => MapEntry(key, grouped[key]!)),
    );
  }

  /// 日ごとのセクションを構築
  Widget _buildDaySection(DateTime date, List<WorkoutSession> sessions) {
    // その日の合計統計を計算
    final totalExercises =
        sessions.fold<int>(0, (sum, s) => sum + s.exerciseCount);
    final totalVolume =
        sessions.fold<double>(0, (sum, s) => sum + s.totalVolume);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日付ヘッダー
          _buildDateHeader(date, totalExercises, totalVolume),
          const SizedBox(height: 12),
          // その日のワークアウト一覧
          ...sessions.map((session) => _buildWorkoutItem(session)),
        ],
      ),
    );
  }

  /// 日付ヘッダー
  Widget _buildDateHeader(DateTime date, int totalExercises, double totalVolume) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.greenPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today,
            size: 16,
            color: AppColors.greenPrimary,
          ),
          const SizedBox(width: 8),
          Text(
            _formatDateHeader(date),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.greenPrimary,
            ),
          ),
          const Spacer(),
          Text(
            '$totalExercises種目',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${totalVolume.round()}kg',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// ワークアウト項目
  Widget _buildWorkoutItem(WorkoutSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.border,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bgSub,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.fitness_center,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${session.exerciseCount}種目 ・ ${session.totalVolume.round()}kg',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }

  /// 日付ヘッダーのフォーマット
  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final weekday = weekdays[date.weekday - 1];

    if (dateOnly == today) {
      return '今日（$weekday）';
    } else if (dateOnly == yesterday) {
      return '昨日（$weekday）';
    } else if (date.year == now.year) {
      return '${date.month}月${date.day}日（$weekday）';
    } else {
      return '${date.year}年${date.month}月${date.day}日（$weekday）';
    }
  }
}
