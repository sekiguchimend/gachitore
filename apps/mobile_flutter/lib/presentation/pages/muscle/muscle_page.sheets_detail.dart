part of 'muscle_page.dart';

extension _MusclePageSheetsDetail on _MusclePageState {
  void _showExerciseDetail(Exercise exercise) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              exercise.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _MusclePageState._muscleEnToJa[exercise.muscleGroup] ??
                  exercise.muscleGroup,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildDetailStat('e1RM', '${exercise.e1rm}kg'),
                ),
                Expanded(
                  child: _buildDetailStat(
                    '前回',
                    '${exercise.lastWeight}kg×${exercise.lastReps}',
                  ),
                ),
                Expanded(
                  child: _buildDetailStat(
                    'トレンド',
                    exercise.trend >= 0
                        ? '+${exercise.trend}kg'
                        : '${exercise.trend}kg',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppOutlinedButton(
                    text: '履歴を見る',
                    icon: Icons.history,
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _showExerciseHistorySheet(exercise);
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    text: '記録する',
                    icon: Icons.add,
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          _showLogSetSheet(exercise);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLogSetSheet(Exercise exercise) {
    final weightController = TextEditingController(
      text: exercise.lastWeight > 0 ? exercise.lastWeight.toString() : '',
    );
    final repsController = TextEditingController(
      text: exercise.lastReps > 0 ? exercise.lastReps.toString() : '',
    );
    bool isLogging = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  exercise.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '重量 (kg)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: weightController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: AppColors.textTertiary,
                              ),
                              filled: true,
                              fillColor: AppColors.bgSub,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '回数',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: repsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: AppColors.textTertiary,
                              ),
                              filled: true,
                              fillColor: AppColors.bgSub,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: '記録する',
                  isLoading: isLogging,
                  onPressed: () async {
                    final weight = double.tryParse(weightController.text);
                    final reps = int.tryParse(repsController.text);

                    if (weight == null || reps == null) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text('重量と回数を入力してください'),
                        ),
                      );
                      return;
                    }

                    setSheetState(() => isLogging = true);

                    try {
                      final workoutService = ref.read(workoutServiceProvider);
                      await workoutService.logWorkout(
                        LogWorkoutRequest(
                          date: DateTime.now(),
                          startTime: DateTime.now(),
                          endTime: DateTime.now(),
                          exercises: [
                            WorkoutExerciseRequest(
                              exerciseId: exercise.id.isNotEmpty ? exercise.id : null,
                              customName: exercise.id.isNotEmpty ? null : exercise.name,
                              muscleTag: exercise.muscleGroup,
                              sets: [
                                WorkoutSetRequest(
                                  weightKg: weight,
                                  reps: reps,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );

                      if (mounted) {
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text('記録しました'),
                          ),
                        );
                        _loadData();
                      }
                    } catch (e) {
                      setSheetState(() => isLogging = false);
                      if (mounted) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text('記録に失敗しました'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showExerciseHistorySheet(Exercise exercise) {
    bool isLoading = true;
    String? errorMessage;
    List<_ExerciseHistoryRow> rows = [];

    Future<void> load() async {
      try {
        final workoutService = ref.read(workoutServiceProvider);
        final sessions = await workoutService.getWorkoutHistory(limit: 30);

        final extracted = <_ExerciseHistoryRow>[];
        for (final s in sessions) {
          final detail = await workoutService.getWorkoutDetails(s.id);
          final dateStr = detail['date']?.toString();
          DateTime? date;
          if (dateStr != null) {
            try {
              date = DateTime.parse(dateStr);
            } catch (_) {}
          }

          final exercises = detail['exercises'];
          if (exercises is! List) continue;

          for (final ex in exercises) {
            if (ex is! Map) continue;
            final exId = ex['exercise_id']?.toString();
            // Workout detail endpoint returns flattened "exercise_name" and "sets"
            // We match by name as fallback if exercise_id isn't present in response shape.
            final exName = ex['exercise_name']?.toString() ?? '';
            final isMatch = (exId != null && exId == exercise.id) ||
                (exName.isNotEmpty && exName == exercise.name);
            if (!isMatch) continue;

            final sets = ex['sets'];
            if (sets is! List) continue;

            for (final set in sets) {
              if (set is! Map) continue;
              final weight = (set['weight_kg'] is num) ? (set['weight_kg'] as num).toDouble() : null;
              final reps = (set['reps'] is num) ? (set['reps'] as num).toInt() : null;
              if (weight == null || reps == null) continue;
              if (weight <= 0 || reps <= 0) continue;

              final e1rm = weight * (1 + reps / 30);
              extracted.add(_ExerciseHistoryRow(
                date: date ?? s.date,
                weight: weight,
                reps: reps,
                e1rm: e1rm,
              ));
            }
          }
        }

        extracted.sort((a, b) => b.date.compareTo(a.date));
        rows = extracted;
        errorMessage = null;
      } catch (e) {
        errorMessage = '履歴の取得に失敗しました: $e';
      } finally {
        isLoading = false;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          if (isLoading) {
            // fire once
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!isLoading) return;
              await load();
              if (mounted) {
                setSheetState(() {});
              }
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${exercise.name}の履歴',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(color: AppColors.greenPrimary),
                    ),
                  )
                else if (errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.error.withOpacity(0.2)),
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.error,
                      ),
                    ),
                  )
                else if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(Icons.history, size: 48, color: AppColors.textTertiary),
                        const SizedBox(height: 12),
                        const Text(
                          '履歴がありません',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  const SizedBox(height: 8),
                  ...rows.map((r) => _buildHistoryRow(r)),
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryRow(_ExerciseHistoryRow row) {
    final date = row.date;
    final weekday = ['月', '火', '水', '木', '金', '土', '日'][date.weekday - 1];
    final dateLabel = '${date.month}/${date.day}（$weekday）';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSub,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dateLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${row.weight.toStringAsFixed(1)}kg × ${row.reps}回',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'e1RM ${row.e1rm.toStringAsFixed(1)}kg',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseHistoryRow {
  final DateTime date;
  final double weight;
  final int reps;
  final double e1rm;

  _ExerciseHistoryRow({
    required this.date,
    required this.weight,
    required this.reps,
    required this.e1rm,
  });
}


