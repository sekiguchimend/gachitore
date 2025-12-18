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

    return RefreshIndicator(
      onRefresh: _loadWorkoutHistory,
      color: AppColors.greenPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recentWorkouts.length,
        itemBuilder: (context, index) {
          return _buildWorkoutHistoryCard(_recentWorkouts[index]);
        },
      ),
    );
  }

  Widget _buildWorkoutHistoryCard(WorkoutSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.greenPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  session.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greenPrimary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(session.date),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildHistoryStat(
                Icons.fitness_center,
                '${session.exerciseCount}種目',
              ),
              const SizedBox(width: 24),
              _buildHistoryStat(
                Icons.timer_outlined,
                '${session.duration.inMinutes}分',
              ),
              const SizedBox(width: 24),
              _buildHistoryStat(
                Icons.show_chart,
                '${(session.totalVolume / 1000).toStringAsFixed(1)}t',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今日';
    } else if (diff.inDays == 1) {
      return '昨日';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日前';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}


