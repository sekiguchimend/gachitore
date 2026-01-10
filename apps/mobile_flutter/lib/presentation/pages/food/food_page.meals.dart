part of 'food_page.dart';

extension _FoodPageMeals on _FoodPageState {
  String _selectedDateLabel() {
    final now = DateTime.now();
    if (_isSameDay(_selectedDate, now)) return '今日';
    final weekday = _getDayName(_selectedDate.weekday);
    return '${_selectedDate.month}/${_selectedDate.day}（$weekday）';
  }

  Widget _buildMealsList() {
    if (_meals.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.restaurant_outlined,
                size: 48,
                color: AppColors.textTertiary,
              ),
              const SizedBox(height: 16),
              Text(
                '${_selectedDateLabel()}の食事を記録しましょう',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_selectedDateLabel()}の食事',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final expansionTheme = Theme.of(context).copyWith(dividerColor: Colors.transparent);
              return Column(
                children: _meals.map((meal) => _buildMealCard(meal, expansionTheme)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(MealEntry meal, ThemeData expansionTheme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: expansionTheme,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getMealColor(meal.type).withValues(alpha:0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getMealIcon(meal.type),
              color: _getMealColor(meal.type),
              size: 20,
            ),
          ),
          title: Text(
            meal.type.displayName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            '${meal.totalCalories} kcal • P ${meal.totalProtein.round()}g',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          trailing: Text(
            '${meal.time.hour}:${meal.time.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          children: [
            ...meal.items.map((item) => _buildMealItemRow(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildMealItemRow(MealItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            '${item.calories} kcal',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMealIcon(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return Icons.wb_sunny_outlined;
      case MealType.lunch:
        return Icons.wb_cloudy_outlined;
      case MealType.dinner:
        return Icons.nights_stay_outlined;
      default:
        return Icons.cookie_outlined;
    }
  }

  Color _getMealColor(MealType type) {
    switch (type) {
      case MealType.breakfast:
        return AppColors.warning;
      case MealType.lunch:
        return AppColors.greenPrimary;
      case MealType.dinner:
        return AppColors.info;
      default:
        return AppColors.textSecondary;
    }
  }
}


