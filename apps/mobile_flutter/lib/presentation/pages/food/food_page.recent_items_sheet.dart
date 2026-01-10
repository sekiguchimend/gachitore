part of 'food_page.dart';

class _RecentFoodItem {
  final MealItem item;
  final DateTime lastTime;

  const _RecentFoodItem({
    required this.item,
    required this.lastTime,
  });
}

extension _FoodPageRecentItemsSheet on _FoodPageState {
  String _weekdayJa(int weekday) {
    const days = ['月', '火', '水', '木', '金', '土', '日'];
    if (weekday < 1 || weekday > 7) return '';
    return days[weekday - 1];
  }

  void _showRecentItemsSheet() {
    bool isLoading = true;
    String? errorMessage;
    MealType selectedMealType = _getMealTypeByTime();
    List<_RecentFoodItem> items = [];

    Future<void> load() async {
      try {
        final mealService = ref.read(mealServiceProvider);
        final recentMeals = await mealService.getRecentMeals(limit: 30);

        // 直近の「食品」単位でユニーク化（同名は最新だけ残す）
        final map = <String, _RecentFoodItem>{};
        for (final meal in recentMeals) {
          for (final it in meal.items) {
            if (it.name.trim().isEmpty) continue;
            map.putIfAbsent(
              it.name,
              () => _RecentFoodItem(item: it, lastTime: meal.time),
            );
          }
        }

        final list = map.values.toList()
          ..sort((a, b) => b.lastTime.compareTo(a.lastTime));

        items = list;
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
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!isLoading) return;
              await load();
              if (mounted) setSheetState(() {});
            });
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
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
                          const Text(
                            '履歴から選ぶ',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: _foodMealTypes.map((type) {
                            final isSelected = selectedMealType == type;
                            return GestureDetector(
                              onTap: () =>
                                  setSheetState(() => selectedMealType = type),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.greenPrimary
                                      : AppColors.bgSub,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  type.displayName,
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
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.greenPrimary,
                          ),
                        )
                      : errorMessage != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            )
                          : items.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.history,
                                          size: 48,
                                          color: AppColors.textTertiary,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          '履歴がありません\nまずは食事を記録してください',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  itemCount: items.length,
                                  itemBuilder: (context, index) {
                                    final it = items[index];
                                    final dateLabel =
                                        '${it.lastTime.month}/${it.lastTime.day}（${_weekdayJa(it.lastTime.weekday)}）';

                                    return GestureDetector(
                                      onTap: () async {
                                        try {
                                          final mealService =
                                              ref.read(mealServiceProvider);
                                          await mealService.logMeal(
                                            LogMealRequest(
                                              date: _selectedDate,
                                              time: DateTime.now(),
                                              mealType: selectedMealType,
                                              items: [
                                                MealItemRequest(
                                                  name: it.item.name,
                                                  calories: it.item.calories,
                                                  proteinG: it.item.protein,
                                                  fatG: it.item.fat,
                                                  carbsG: it.item.carbs,
                                                ),
                                              ],
                                            ),
                                          );

                                          if (!mounted) return;
                                          Navigator.of(sheetContext).pop();
                                          ScaffoldMessenger.of(sheetContext)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text('記録しました'),
                                            ),
                                          );
                                          _loadData();
                                        } catch (e) {
                                          if (!mounted) return;
                                          ScaffoldMessenger.of(sheetContext)
                                              .showSnackBar(
                                            SnackBar(
                                              content:
                                                  Text('記録に失敗しました: $e'),
                                            ),
                                          );
                                        }
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: AppColors.bgSub,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: AppColors.greenPrimary
                                                    .withValues(alpha:0.15),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: const Icon(
                                                Icons.restaurant,
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
                                                    it.item.name,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${it.item.calories}kcal • P${it.item.protein.round()}g F${it.item.fat.round()}g C${it.item.carbs.round()}g',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          AppColors.textTertiary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '最後に食べた日: $dateLabel',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          AppColors.textTertiary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const Icon(
                                              Icons.add_circle_outline,
                                              color: AppColors.greenPrimary,
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


