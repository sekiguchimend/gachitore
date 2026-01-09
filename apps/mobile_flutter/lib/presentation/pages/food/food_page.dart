import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/meal_models.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/info_tooltip.dart';

part 'food_page.sections.dart';
part 'food_page.meals.dart';
part 'food_page.add_meal_sheet.dart';
part 'food_page.manual_input_sheet.dart';
part 'food_page.recent_items_sheet.dart';

// Food page shared constants
const List<MealType> _foodMealTypes = [
  MealType.breakfast,
  MealType.lunch,
  MealType.dinner,
  MealType.snack,
];

class FoodPage extends ConsumerStatefulWidget {
  const FoodPage({super.key});

  @override
  ConsumerState<FoodPage> createState() => _FoodPageState();
}

class _FoodPageState extends ConsumerState<FoodPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  NutritionSummary? _nutritionSummary;
  List<MealEntry> _meals = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final mealService = ref.read(mealServiceProvider);
      final results = await Future.wait([
        mealService.getNutritionSummary(_selectedDate),
        mealService.getMealsForDate(_selectedDate),
      ]);

      if (mounted) {
        setState(() {
          _nutritionSummary = results[0] as NutritionSummary;
          _meals = results[1] as List<MealEntry>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onDateChanged(DateTime date) {
    setState(() => _selectedDate = date);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.greenPrimary,
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.greenPrimary,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDateSelector(),
                            _buildNutritionSummary(),
                            _buildPfcChart(),
                            _buildMealsList(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddMealSheet(),
        backgroundColor: AppColors.greenPrimary,
        icon: const Icon(Icons.add, color: AppColors.textPrimary),
        label: const Text(
          '食事を追加',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
