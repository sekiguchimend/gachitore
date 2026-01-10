part of 'muscle_page.dart';

extension _MusclePageSheetsStart on _MusclePageState {
  // テンプレート名から対応する筋肉グループへのマッピング
  static const Map<String, List<String>> _templateToMuscles = {
    '胸・三頭': ['chest', 'triceps'],
    '背中・二頭': ['back', 'biceps'],
    '脚': ['quadriceps', 'hamstrings', 'glutes', 'calves'],
    '肩': ['shoulder'],
    'Push': ['chest', 'shoulder', 'triceps'],
    'Pull': ['back', 'biceps'],
  };

  void _showStartWorkoutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
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
              const Text(
                'ワークアウトを開始',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'テンプレートを選択するか、空のワークアウトを開始',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildWorkoutTemplate(
                      sheetContext,
                      '履歴からコピー',
                      '前回のメニューを呼び出す',
                      Icons.copy_outlined,
                      isCopyFromHistory: true,
                    ),
                    _buildWorkoutTemplate(
                      sheetContext,
                      '空のワークアウト',
                      '種目を自由に追加',
                      Icons.add_circle_outline,
                      isEmpty: true,
                    ),
                    _buildWorkoutTemplate(
                      sheetContext,
                      '胸・三頭',
                      'ベンチプレス、ダンベルフライなど',
                      Icons.favorite_outline,
                    ),
                    _buildWorkoutTemplate(
                      sheetContext,
                      '背中・二頭',
                      'デッドリフト、ラットプルなど',
                      Icons.sync_alt,
                    ),
                    _buildWorkoutTemplate(
                      sheetContext,
                      '脚',
                      'スクワット、レッグプレスなど',
                      Icons.directions_walk,
                    ),
                    _buildWorkoutTemplate(
                      sheetContext,
                      '肩',
                      'OHP、サイドレイズなど',
                      Icons.arrow_upward,
                    ),
                    _buildWorkoutTemplate(
                      sheetContext,
                      'Push',
                      '押す動作の種目',
                      Icons.arrow_forward,
                    ),
                    _buildWorkoutTemplate(
                      sheetContext,
                      'Pull',
                      '引く動作の種目',
                      Icons.arrow_back,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutTemplate(
    BuildContext sheetContext,
    String name,
    String description,
    IconData icon, {
    bool isEmpty = false,
    bool isCopyFromHistory = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.of(sheetContext).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            if (isCopyFromHistory) {
              _showCopyWorkoutFromHistorySheet();
            } else if (isEmpty) {
              _showExerciseSelectionSheet();
            } else {
              // テンプレートに対応する筋肉グループでフィルタリング
              final targetMuscles = _templateToMuscles[name] ?? [];
              _showExerciseSelectionSheet(
                templateName: name,
                filterMuscles: targetMuscles,
              );
            }
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSub,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.greenPrimary.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.greenPrimary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
  }

  void _showExerciseSelectionSheet({
    String? templateName,
    List<String>? filterMuscles,
  }) {
    int selectedFilter = 0;
    String searchQuery = '';

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
          // フィルタリング: 検索 + 部位（またはテンプレート）
          List<Exercise> filtered = _exercises;

          // テンプレートが指定されている場合は、テンプレートの筋肉グループでフィルタリング
          if (filterMuscles != null && filterMuscles.isNotEmpty) {
            filtered = filtered
                .where((e) => filterMuscles.contains(e.muscleGroup))
                .toList();
          }

          if (searchQuery.isNotEmpty) {
            filtered = filtered
                .where((e) =>
                    e.name.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();
          }

          // テンプレートが指定されていない場合のみ、部位フィルターを適用
          if (filterMuscles == null && selectedFilter > 0) {
            final group = _muscleGroups[selectedFilter];
            final targetMuscles = _MusclePageState._muscleJaToEn[group] ?? [];
            filtered = filtered
                .where((e) => targetMuscles.contains(e.muscleGroup))
                .toList();
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  templateName != null
                                      ? '$templateName - 種目を選択'
                                      : '種目を選択',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (templateName != null)
                                  Text(
                                    '${filtered.length}件の種目',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 検索バー
                      TextField(
                        onChanged: (value) =>
                            setSheetState(() => searchQuery = value),
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '種目を検索...',
                          hintStyle: TextStyle(color: AppColors.textTertiary),
                          prefixIcon: const Icon(Icons.search,
                              color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.bgSub,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                // 部位フィルター（テンプレートが指定されていない場合のみ表示）
                if (templateName == null) ...[
                  SizedBox(
                    height: 40,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _muscleGroups.length,
                      itemBuilder: (context, index) {
                        final isSelected = selectedFilter == index;
                        return GestureDetector(
                          onTap: () =>
                              setSheetState(() => selectedFilter = index),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.greenPrimary
                                  : AppColors.bgSub,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _muscleGroups[index],
                              style: TextStyle(
                                fontSize: 13,
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
                  ),
                  const SizedBox(height: 12),
                ],
                // 種目リスト
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            '種目が見つかりません',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final exercise = filtered[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(sheetContext).pop();
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) {
                                    _showLogSetSheet(exercise);
                                  }
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.bgSub,
                                  borderRadius: BorderRadius.circular(12),
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
                                        Icons.fitness_center,
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
                                            exercise.name,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _MusclePageState._muscleEnToJa[
                                                    exercise.muscleGroup] ??
                                                exercise.muscleGroup,
                                            style: TextStyle(
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
}


