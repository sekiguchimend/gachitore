part of 'muscle_page.dart';

class _CopiedWorkoutMenuItem {
  final Exercise exercise;
  final int setCount;

  const _CopiedWorkoutMenuItem({
    required this.exercise,
    required this.setCount,
  });
}

extension _MusclePageCopyWorkout on _MusclePageState {
  String _weekdayJa(int weekday) {
    const days = ['月', '火', '水', '木', '金', '土', '日'];
    if (weekday < 1 || weekday > 7) return '';
    return days[weekday - 1];
  }

  void _showCopyWorkoutFromHistorySheet() {
    bool isLoading = false;
    String? errorMessage;
    List<WorkoutSession> sessions = List.of(_recentWorkouts);

    Future<void> load() async {
      try {
        final workoutService = ref.read(workoutServiceProvider);
        final history = await workoutService.getWorkoutHistory(limit: 30);
        sessions = history;
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
          // 初回だけロード（すでに履歴があっても念のため最新化）
          if (!isLoading && sessions.isEmpty && errorMessage == null) {
            isLoading = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              await load();
              if (mounted) setSheetState(() {});
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.75,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '履歴からコピー',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.greenPrimary,
                      ),
                    ),
                  )
                else if (errorMessage != null)
                  Expanded(
                    child: Center(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else if (sessions.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'コピーできる履歴がありません',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: sessions.length,
                      itemBuilder: (context, index) {
                        final s = sessions[index];
                        final dateLabel =
                            '${s.date.month}/${s.date.day}（${_weekdayJa(s.date.weekday)}）';

                        return GestureDetector(
                          onTap: () async {
                            setSheetState(() {
                              isLoading = true;
                              errorMessage = null;
                            });

                            try {
                              final workoutService =
                                  ref.read(workoutServiceProvider);
                              final detail =
                                  await workoutService.getWorkoutDetails(s.id);

                              final items = _parseWorkoutDetailToMenuItems(
                                detail,
                                fallbackName: s.name,
                              );

                              if (!mounted) return;
                              Navigator.of(sheetContext).pop();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  _showCopiedWorkoutMenuSheet(
                                    title: '$dateLabel の ${s.name}',
                                    items: items,
                                  );
                                }
                              });
                            } catch (e) {
                              setSheetState(() {
                                isLoading = false;
                                errorMessage = '詳細の取得に失敗しました: $e';
                              });
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.bgSub,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.greenPrimary
                                        .withValues(alpha:0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.copy_outlined,
                                    color: AppColors.greenPrimary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$dateLabel ・ ${s.exerciseCount}種目',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_CopiedWorkoutMenuItem> _parseWorkoutDetailToMenuItems(
    Map<String, dynamic> detail, {
    required String fallbackName,
  }) {
    final rawExercises = detail['exercises'];
    if (rawExercises is! List) return const [];

    final items = <_CopiedWorkoutMenuItem>[];

    for (final raw in rawExercises) {
      if (raw is! Map) continue;
      final exId = raw['exercise_id']?.toString();
      final exName = raw['exercise_name']?.toString().trim();
      final muscleTag = raw['muscle_tag']?.toString().trim();
      final sets = raw['sets'];
      final setCount = sets is List ? sets.length : 0;

      if (exName == null || exName.isEmpty) continue;

      // 既存の種目リストから見つかれば、前回値なども活かす
      final fromList = exId != null && exId.isNotEmpty
          ? _exercises.where((e) => e.id == exId).toList()
          : const <Exercise>[];

      final exercise = fromList.isNotEmpty
          ? fromList.first
          : Exercise(
              id: exId ?? '',
              name: exName,
              muscleGroup: muscleTag ?? '',
              e1rm: 0,
              lastWeight: 0,
              lastReps: 0,
              trend: 0,
            );

      items.add(_CopiedWorkoutMenuItem(exercise: exercise, setCount: setCount));
    }

    // 名前だけで筋肉タグが取れない場合があるので、空のものは最後に回す
    items.sort((a, b) {
      final aHas = a.exercise.muscleGroup.isNotEmpty ? 0 : 1;
      final bHas = b.exercise.muscleGroup.isNotEmpty ? 0 : 1;
      return aHas.compareTo(bHas);
    });

    return items;
  }

  void _showCopiedWorkoutMenuSheet({
    required String title,
    required List<_CopiedWorkoutMenuItem> items,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
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
            const SizedBox(height: 6),
            const Text(
              '前回の種目一覧を呼び出しました。記録したい種目をタップしてください。',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'コピーできる種目がありません',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
              ...items.map((it) {
                final muscleJa = _MusclePageState
                        ._muscleEnToJa[it.exercise.muscleGroup] ??
                    (it.exercise.muscleGroup.isNotEmpty
                        ? it.exercise.muscleGroup
                        : '部位未設定');

                return GestureDetector(
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _showLogSetSheet(it.exercise);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgSub,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.greenPrimary.withValues(alpha:0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.fitness_center,
                            color: AppColors.greenPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                it.exercise.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$muscleJa ・ 前回 ${it.setCount}セット',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.textTertiary,
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}


