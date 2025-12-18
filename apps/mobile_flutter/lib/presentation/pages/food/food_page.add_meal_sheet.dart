part of 'food_page.dart';

extension _FoodPageAddMealSheet on _FoodPageState {
  // 食事タイプの選択肢
  static const List<MealType> _mealTypes = [
    MealType.breakfast,
    MealType.lunch,
    MealType.dinner,
    MealType.snack,
  ];

  void _showAddMealSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.of(sheetContext).padding.bottom;
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.75;

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
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
                    const Text(
                      '食事を追加',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAddMealOption(
                      sheetContext,
                      Icons.camera_alt_outlined,
                      '写真から追加',
                      'AIが食事を認識します',
                      () {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _showPhotoAddSheet();
                          }
                        });
                      },
                    ),
                    _buildAddMealOption(
                      sheetContext,
                      Icons.search,
                      '食品を検索',
                      'データベースから検索',
                      () {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _showFoodSearchSheet();
                          }
                        });
                      },
                    ),
                    _buildAddMealOption(
                      sheetContext,
                      Icons.edit_outlined,
                      '手動で入力',
                      'カスタム食事を作成',
                      () {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _showManualInputSheet();
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddMealOption(
    BuildContext sheetContext,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        Navigator.of(sheetContext).pop();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.greenPrimary.withOpacity(0.15),
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
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
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

  /// 入力フィールドを構築
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
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
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textTertiary),
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
    );
  }

  /// 現在時刻から食事タイプを推定
  MealType _getMealTypeByTime() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 10) {
      return MealType.breakfast;
    } else if (hour >= 10 && hour < 15) {
      return MealType.lunch;
    } else if (hour >= 15 && hour < 21) {
      return MealType.dinner;
    } else {
      return MealType.snack;
    }
  }
}


