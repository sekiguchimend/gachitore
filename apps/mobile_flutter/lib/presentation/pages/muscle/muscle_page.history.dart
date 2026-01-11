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

    // パフォーマンス最適化: 日付ごとのグループ化をキャッシュ
    final groupedWorkouts = _getGroupedWorkouts();

    return RefreshIndicator(
      onRefresh: _loadWorkoutHistory,
      color: AppColors.greenPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // GitHub草スタイルのコントリビューショングラフ
            _buildContributionGraph(),
            const SizedBox(height: 24),
            // ワークアウト履歴リスト
            if (_recentWorkouts.isEmpty)
              _buildEmptyState()
            else
              ...groupedWorkouts.entries.map(
                (entry) => _buildDaySection(entry.key, entry.value),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
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

  // 定数
  static const int _weeksToShow = 16;
  static const int _daysInWeek = 7;

  /// パフォーマンス最適化: グループ化されたワークアウトを取得（キャッシュ付き）
  Map<DateTime, List<WorkoutSession>> _getGroupedWorkouts() {
    if (_cachedGroupedWorkouts != null &&
        _lastWorkoutsForCache == _recentWorkouts) {
      return _cachedGroupedWorkouts!;
    }
    _cachedGroupedWorkouts = _groupWorkoutsByDate(_recentWorkouts);
    _lastWorkoutsForCache = _recentWorkouts;
    return _cachedGroupedWorkouts!;
  }

  /// パフォーマンス最適化: スコアマップを取得（キャッシュ付き）
  Map<DateTime, double> _getScoreMap() {
    if (_cachedScoreMap != null &&
        _lastWorkoutsForCache == _recentWorkouts) {
      return _cachedScoreMap!;
    }
    _cachedScoreMap = _computeScoreMap();
    _lastWorkoutsForCache = _recentWorkouts;
    return _cachedScoreMap!;
  }

  /// スコアマップを計算（ボリューム/体重）
  Map<DateTime, double> _computeScoreMap() {
    final scoreMap = <DateTime, double>{};
    for (final workout in _recentWorkouts) {
      final dateKey = DateTime(
        workout.date.year,
        workout.date.month,
        workout.date.day,
      );
      final volume = (scoreMap[dateKey] ?? 0) + workout.totalVolume;
      if (_bodyWeight != null && _bodyWeight! > 0) {
        scoreMap[dateKey] = volume / _bodyWeight!;
      } else {
        scoreMap[dateKey] = volume;
      }
    }
    return scoreMap;
  }

  /// GitHub草スタイルのコントリビューショングラフ
  Widget _buildContributionGraph() {
    // パフォーマンス最適化: DateTime.now()を一度だけ呼び出し
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // 今週の日曜日を取得（週の開始）
    final currentWeekStart = todayDate.subtract(Duration(days: todayDate.weekday % 7));

    // 16週間前の日曜日
    final startDate = currentWeekStart.subtract(const Duration(days: (_weeksToShow - 1) * 7));

    // パフォーマンス最適化: キャッシュされたスコアマップを使用
    final scoreMap = _getScoreMap();

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
                '${_recentWorkouts.length}回',
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
                        ? Border.all(color: AppColors.border.withValues(alpha: 0.3), width: 0.5)
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

  /// スコア（総ボリューム/体重）に基づいて色を取得
  /// 基準: 80未満=薄緑, 80-120=中緑, 120-160=濃緑, 160以上=最濃緑
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
    // パフォーマンス最適化: DateTime.now()の呼び出しを最小化
    // この関数は複数回呼ばれる可能性があるが、キャッシュは複雑なので保留
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
