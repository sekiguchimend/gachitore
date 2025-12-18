part of 'food_page.dart';

extension _FoodPageManualInputSheet on _FoodPageState {
  /// 手動入力シート（photoUrlがある場合は食事ログに紐づける）
  void _showManualInputSheet({String? photoUrl}) {
    final nameController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final fatController = TextEditingController();
    final carbsController = TextEditingController();
    MealType selectedMealType = _getMealTypeByTime();
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
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '手動で入力',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                if (photoUrl != null) ...[
                  const SizedBox(height: 8),
                  const Text(
                    '写真を添付して記録します（内容は手動入力）',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.bgSub,
                          alignment: Alignment.center,
                          child: const Text(
                            '画像を表示できませんでした',
                            style: TextStyle(color: AppColors.textTertiary),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  '食事タイプ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _mealTypes.map((type) {
                    final isSelected = selectedMealType == type;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedMealType = type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.greenPrimary : AppColors.bgSub,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          type.displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _buildInputField(
                  controller: nameController,
                  label: '食品名',
                  hint: '例: ご飯、鶏むね肉',
                ),
                const SizedBox(height: 12),
                _buildInputField(
                  controller: caloriesController,
                  label: 'カロリー (kcal)',
                  hint: '0',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInputField(
                        controller: proteinController,
                        label: 'P (g)',
                        hint: '0',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInputField(
                        controller: fatController,
                        label: 'F (g)',
                        hint: '0',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildInputField(
                        controller: carbsController,
                        label: 'C (g)',
                        hint: '0',
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: '記録する',
                  isLoading: isLogging,
                  onPressed: () async {
                    final name = nameController.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(content: Text('食品名を入力してください')),
                      );
                      return;
                    }

                    setSheetState(() => isLogging = true);

                    try {
                      final mealService = ref.read(mealServiceProvider);
                      await mealService.logMeal(
                        LogMealRequest(
                          date: _selectedDate,
                          time: DateTime.now(),
                          mealType: selectedMealType,
                          photoUrl: photoUrl,
                          items: [
                            MealItemRequest(
                              name: name,
                              calories: int.tryParse(caloriesController.text) ?? 0,
                              proteinG: double.tryParse(proteinController.text),
                              fatG: double.tryParse(fatController.text),
                              carbsG: double.tryParse(carbsController.text),
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
                      setSheetState(() => isLogging = false);
                      if (!mounted) return;
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        SnackBar(content: Text('記録に失敗しました: $e')),
                      );
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
}


