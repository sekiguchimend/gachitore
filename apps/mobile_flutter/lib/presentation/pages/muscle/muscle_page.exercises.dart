part of 'muscle_page.dart';

extension _MusclePageExercises on _MusclePageState {
  Widget _buildExercisesTab() {
    return Column(
      children: [
        // Muscle Group Filter
        _buildMuscleGroupFilter(),

        // Exercises List
        Expanded(
          child: _isLoadingExercises
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.greenPrimary,
                  ),
                )
              : _filteredExercises.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fitness_center,
                              size: 48,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedMuscleGroup == 0
                                  ? 'まだトレーニング記録がありません'
                                  : 'この部位の記録がありません',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '下の「ワークアウト開始」ボタンから\n種目を記録しましょう',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadExercises,
                      color: AppColors.greenPrimary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredExercises.length,
                        itemBuilder: (context, index) {
                          return _buildExerciseCard(_filteredExercises[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildMuscleGroupFilter() {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _muscleGroups.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedMuscleGroup == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedMuscleGroup = index),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.greenPrimary : AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isSelected ? AppColors.greenPrimary : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _muscleGroups[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise) {
    return GestureDetector(
      onTap: () => _showExerciseDetail(exercise),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.greenPrimary.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fitness_center,
                color: AppColors.greenPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '前回: ${exercise.lastWeight}kg × ${exercise.lastReps}回',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // e1RM
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Text(
                      'e1RM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${exercise.e1rm.toStringAsFixed(1)}kg',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _buildTrendIndicator(exercise.trend),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(double trend) {
    if (trend == 0) {
      return const Text(
        '→ 維持',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary,
        ),
      );
    }

    final isPositive = trend > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPositive ? Icons.trending_up : Icons.trending_down,
          size: 14,
          color: isPositive ? AppColors.success : AppColors.error,
        ),
        const SizedBox(width: 4),
        Text(
          '${isPositive ? '+' : ''}${trend.toStringAsFixed(1)}kg',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isPositive ? AppColors.success : AppColors.error,
          ),
        ),
      ],
    );
  }
}


