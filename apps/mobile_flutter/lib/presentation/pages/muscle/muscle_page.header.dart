part of 'muscle_page.dart';

extension _MusclePageHeader on _MusclePageState {
  Widget _buildHeader() {
    final tabs = ['種目', '履歴'];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: PopupMenuButton<int>(
                offset: const Offset(0, 48),
                color: AppColors.bgCard,
                useRootNavigator: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (index) {
                  _tabController.animateTo(index);
                  setState(() {});
                },
                itemBuilder: (context) => [
                  PopupMenuItem<int>(
                    value: 0,
                    child: Row(
                      children: [
                        Icon(
                          _tabController.index == 0
                              ? Icons.check
                              : Icons.fitness_center,
                          size: 18,
                          color: _tabController.index == 0
                              ? AppColors.greenPrimary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '種目',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _tabController.index == 0
                                ? AppColors.greenPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<int>(
                    value: 1,
                    child: Row(
                      children: [
                        Icon(
                          _tabController.index == 1
                              ? Icons.check
                              : Icons.history,
                          size: 18,
                          color: _tabController.index == 1
                              ? AppColors.greenPrimary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '履歴',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _tabController.index == 1
                                ? AppColors.greenPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tabs[_tabController.index],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_less,
                      color: AppColors.textSecondary,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      _showStatsSheet();
                    },
                    icon: const Icon(
                      Icons.bar_chart,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _showAddExerciseSheet();
                    },
                    icon: const Icon(
                      Icons.add,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: AppColors.greenPrimary,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
        tabs: const [
          Tab(text: '種目'),
          Tab(text: '履歴'),
        ],
      ),
    );
  }

  void _showStatsSheet() {
    final recordedExercises = _recordedExercises;
    final best = recordedExercises.isEmpty
        ? null
        : (recordedExercises.toList()
          ..sort((a, b) => b.e1rm.compareTo(a.e1rm)))
            .first;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.9,
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
                const Text(
                  '統計',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '記録済み種目 ${recordedExercises.length}件 ・ 履歴 ${_recentWorkouts.length}件',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (best != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSub,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.greenPrimary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.emoji_events,
                        color: AppColors.greenPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ベストe1RM（直近30日）',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${best.name}  ${best.e1rm.toStringAsFixed(1)}kg',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppOutlinedButton(
                      text: '詳細',
                      icon: Icons.chevron_right,
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _showExerciseDetail(best);
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgSub,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ヒント',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ここでは直近データから簡易的に集計しています。\n'
                    'より詳しい推移は各種目の「履歴を見る」から確認できます。',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showAddExerciseSheet() {
    final nameController = TextEditingController();
    String primaryMuscle = 'chest';
    String? equipment;
    bool isSaving = false;

    const primaryOptions = <Map<String, String>>[
      {'label': '胸', 'value': 'chest'},
      {'label': '背中', 'value': 'back'},
      {'label': '肩', 'value': 'shoulder'},
      {'label': '二頭（腕）', 'value': 'biceps'},
      {'label': '三頭（腕）', 'value': 'triceps'},
      {'label': '脚（大腿四頭）', 'value': 'quadriceps'},
      {'label': '脚（ハム）', 'value': 'hamstrings'},
      {'label': '脚（尻）', 'value': 'glutes'},
      {'label': '脚（カーフ）', 'value': 'calves'},
      {'label': '腹', 'value': 'abs'},
    ];

    const equipmentOptions = <Map<String, String?>>[
      {'label': '未指定', 'value': null},
      {'label': 'バーベル', 'value': 'barbell'},
      {'label': 'ダンベル', 'value': 'dumbbell'},
      {'label': 'マシン', 'value': 'machine'},
      {'label': 'ケーブル', 'value': 'cable'},
      {'label': '自重', 'value': 'bodyweight'},
      {'label': 'ケトルベル', 'value': 'kettlebell'},
      {'label': 'バンド', 'value': 'band'},
    ];

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
              Row(
                children: [
                  const Text(
                    '新規種目',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: '例：インクラインベンチプレス',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  filled: true,
                  fillColor: AppColors.bgSub,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildLabeledDropdown<String>(
                label: '主な部位',
                value: primaryMuscle,
                items: primaryOptions
                    .map((m) => DropdownMenuItem<String>(
                          value: m['value']!,
                          child: Text(m['label']!),
                        ))
                    .toList(growable: false),
                onChanged: (v) => setSheetState(() => primaryMuscle = v ?? primaryMuscle),
              ),
              const SizedBox(height: 12),
              _buildLabeledDropdown<String?>(
                label: '器具',
                value: equipment,
                items: equipmentOptions
                    .map((m) => DropdownMenuItem<String?>(
                          value: m['value'],
                          child: Text(m['label']!),
                        ))
                    .toList(growable: false),
                onChanged: (v) => setSheetState(() => equipment = v),
              ),
              const SizedBox(height: 16),
              AppButton(
                text: '追加する',
                isLoading: isSaving,
                onPressed: isSaving
                    ? null
                    : () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            const SnackBar(content: Text('種目名を入力してください')),
                          );
                          return;
                        }
                        setSheetState(() => isSaving = true);
                        try {
                          final workoutService = ref.read(workoutServiceProvider);
                          await workoutService.createExercise(
                            name: name,
                            primaryMuscle: primaryMuscle,
                            equipment: equipment,
                          );
                          if (!mounted) return;
                          Navigator.of(sheetContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('種目を追加しました')),
                          );
                          _loadExercises();
                        } catch (e) {
                          setSheetState(() => isSaving = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(sheetContext).showSnackBar(
                            SnackBar(content: Text('追加に失敗しました: $e')),
                          );
                        }
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabeledDropdown<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.bgSub,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              items: items,
              isExpanded: true,
              icon: const Icon(Icons.expand_more, color: AppColors.textSecondary),
              dropdownColor: AppColors.bgCard,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}


