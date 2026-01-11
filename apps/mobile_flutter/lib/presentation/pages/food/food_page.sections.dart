part of 'food_page.dart';

extension _FoodPageSections on _FoodPageState {
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Center(
              child: Text(
                '食事記録',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: IconButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    _onDateChanged(picked);
                  }
                },
                icon: const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    // パフォーマンス最適化: DateTime.now()を一度だけ呼び出し
    final now = DateTime.now();
    final dates = List.generate(7, (i) => now.subtract(Duration(days: 6 - i)));

    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: dates.length,
        itemBuilder: (context, index) {
          final date = dates[index];
          final isSelected = _isSameDay(date, _selectedDate);
          final isToday = _isSameDay(date, now);

          return GestureDetector(
            onTap: () => _onDateChanged(date),
            child: Container(
              width: 48,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.greenPrimary : AppColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: isToday && !isSelected
                    ? Border.all(color: AppColors.greenPrimary)
                    : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getDayName(date.weekday),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNutritionSummary() {
    final summary = _nutritionSummary;
    if (summary == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildNutrientCard(
              'カロリー',
              summary.calories,
              summary.caloriesGoal,
              'kcal',
              AppColors.warning,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildNutrientCard(
              'タンパク質',
              summary.protein,
              summary.proteinGoal,
              'g',
              AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientCard(
    String label,
    int current,
    int goal,
    String unit,
    Color color,
  ) {
    final progress = goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0.0;
    final remaining = goal - current;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                current.toString(),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              Text(
                ' / $goal$unit',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.bgSub,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            remaining > 0 ? '残り $remaining$unit' : '目標達成！',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: remaining > 0 ? AppColors.textTertiary : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPfcChart() {
    final summary = _nutritionSummary;
    if (summary == null) return const SizedBox.shrink();

    return _PfcChartWidget(summary: summary);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getDayName(int weekday) {
    const days = ['月', '火', '水', '木', '金', '土', '日'];
    return days[weekday - 1];
  }
}

/// PFCチャートウィジェット（パフォーマンス最適化のため分離）
class _PfcChartWidget extends StatelessWidget {
  final NutritionSummary summary;

  const _PfcChartWidget({required this.summary});

  @override
  Widget build(BuildContext context) {
    // パフォーマンス最適化: 計算を一度だけ実行
    final total = summary.protein + summary.fat + summary.carbs;
    final proteinRatio = total > 0 ? summary.protein / total : 0.0;
    final fatRatio = total > 0 ? summary.fat / total : 0.0;
    final carbsRatio = total > 0 ? summary.carbs / total : 0.0;

    final proteinPercent = (proteinRatio * 100).round();
    final fatPercent = (fatRatio * 100).round();
    final carbsPercent = (carbsRatio * 100).round();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
              const Text(
                'PFCバランス',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              const InfoTooltip(
                explanation: 'PFCとは、Protein（タンパク質）、Fat（脂質）、Carbohydrate（炭水化物）の頭文字を取った略語です。\n\n三大栄養素のバランスを表し、筋トレや体づくりにおいて重要な指標となります。\n\n・P（タンパク質）：筋肉の材料\n・F（脂質）：ホルモンの材料\n・C（炭水化物）：エネルギー源',
                size: 14,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 24,
                        child: Row(
                          children: [
                            Expanded(
                              flex: proteinPercent.clamp(1, 100),
                              child: Container(color: AppColors.error),
                            ),
                            Expanded(
                              flex: fatPercent.clamp(1, 100),
                              child: Container(color: AppColors.warning),
                            ),
                            Expanded(
                              flex: carbsPercent.clamp(1, 100),
                              child: Container(color: AppColors.info),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPfcLegend(
                          'P',
                          '$proteinPercent%',
                          AppColors.error,
                        ),
                        _buildPfcLegend(
                          'F',
                          '$fatPercent%',
                          AppColors.warning,
                        ),
                        _buildPfcLegend(
                          'C',
                          '$carbsPercent%',
                          AppColors.info,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPfcLegend(String label, String value, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$label $value',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}


