part of 'food_page.dart';

extension _FoodPageFoodSearchSheet on _FoodPageState {
  /// 食品検索シート
  void _showFoodSearchSheet() {
    final searchController = TextEditingController();
    List<MealItem> searchResults = [];
    bool isSearching = false;
    MealType selectedMealType = _getMealTypeByTime();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      useRootNavigator: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => DraggableScrollableSheet(
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
                          '食品を検索',
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
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _mealTypes.map((type) {
                          final isSelected = selectedMealType == type;
                          return GestureDetector(
                            onTap: () => setSheetState(() => selectedMealType = type),
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.greenPrimary : AppColors.bgSub,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                type.displayName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: searchController,
                      onSubmitted: (value) async {
                        if (value.trim().isEmpty) return;
                        setSheetState(() => isSearching = true);
                        try {
                          final mealService = ref.read(mealServiceProvider);
                          final results = await mealService.searchFood(value.trim());
                          setSheetState(() {
                            searchResults = results;
                            isSearching = false;
                          });
                        } catch (_) {
                          setSheetState(() => isSearching = false);
                        }
                      },
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: '食品名を入力...',
                        hintStyle: TextStyle(color: AppColors.textTertiary),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.bgSub,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: isSearching
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.greenPrimary),
                      )
                    : searchResults.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: AppColors.textTertiary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    searchController.text.isEmpty
                                        ? '食品名を検索してください'
                                        : '検索結果がありません\n手動入力をお試しください',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  if (searchController.text.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    AppOutlinedButton(
                                      text: '手動で入力する',
                                      onPressed: () {
                                        Navigator.of(sheetContext).pop();
                                        WidgetsBinding.instance.addPostFrameCallback((_) {
                                          if (mounted) {
                                            _showManualInputSheet();
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: searchResults.length,
                            itemBuilder: (context, index) {
                              final item = searchResults[index];
                              return _buildFoodSearchResult(
                                sheetContext,
                                item,
                                selectedMealType,
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 検索結果アイテム
  Widget _buildFoodSearchResult(
    BuildContext sheetContext,
    MealItem item,
    MealType mealType,
  ) {
    return GestureDetector(
      onTap: () async {
        try {
          final mealService = ref.read(mealServiceProvider);
          await mealService.logMeal(
            LogMealRequest(
              date: _selectedDate,
              time: DateTime.now(),
              mealType: mealType,
              items: [
                MealItemRequest(
                  name: item.name,
                  calories: item.calories,
                  proteinG: item.protein,
                  fatG: item.fat,
                  carbsG: item.carbs,
                ),
              ],
            ),
          );

          if (!mounted) return;
          Navigator.of(sheetContext).pop();
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            const SnackBar(content: Text('記録しました')),
          );
          _loadData();
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(sheetContext).showSnackBar(
            SnackBar(content: Text('記録に失敗しました: $e')),
          );
        }
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
                color: AppColors.greenPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.calories}kcal • P${item.protein.round()}g F${item.fat.round()}g C${item.carbs.round()}g',
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
              Icons.add_circle_outline,
              color: AppColors.greenPrimary,
            ),
          ],
        ),
      ),
    );
  }
}


