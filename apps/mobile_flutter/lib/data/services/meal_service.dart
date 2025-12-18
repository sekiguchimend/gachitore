import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../models/meal_models.dart';

class MealService {
  final ApiClient _apiClient;

  MealService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  /// Log a meal
  Future<LogMealResponse> logMeal(LogMealRequest request) async {
    try {
      final response = await _apiClient.post(
        '/log/meal',
        data: request.toJson(),
      );

      return LogMealResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get meals for a specific date
  Future<List<MealEntry>> getMealsForDate(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final response = await _apiClient.get(
        '/meals',
        queryParameters: {'date': dateStr},
      );

      final meals = response.data as List;
      return meals.map((m) {
        return MealEntry(
          id: m['id'],
          type: MealType.fromString(m['meal_type']),
          time: _parseTime(m['date'], m['time']),
          items: (m['items'] as List?)
                  ?.map((i) => MealItem(
                        name: i['name'],
                        calories: i['calories'] ?? 0,
                        protein: (i['protein_g'] ?? 0).toDouble(),
                        fat: (i['fat_g'] ?? 0).toDouble(),
                        carbs: (i['carbs_g'] ?? 0).toDouble(),
                      ))
                  .toList() ??
              [],
        );
      }).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get nutrition summary for a date
  Future<NutritionSummary> getNutritionSummary(DateTime date) async {
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final response = await _apiClient.get(
        '/meals/nutrition',
        queryParameters: {'date': dateStr},
      );

      final data = response.data;
      return NutritionSummary(
        calories: data['calories'] ?? 0,
        caloriesGoal: data['calories_goal'] ?? 2400,
        protein: data['protein'] ?? 0,
        proteinGoal: data['protein_goal'] ?? 150,
        fat: data['fat'] ?? 0,
        fatGoal: data['fat_goal'] ?? 80,
        carbs: data['carbs'] ?? 0,
        carbsGoal: data['carbs_goal'] ?? 250,
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Delete a meal
  Future<void> deleteMeal(String mealId) async {
    try {
      await _apiClient.delete('/meals/$mealId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Search food database (placeholder - would integrate with food API)
  Future<List<MealItem>> searchFood(String query) async {
    // 外部APIは未導入のため、まずはアプリ内の簡易食品データベースで検索する
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    const foods = <MealItem>[
      MealItem(name: '白米（茶碗1杯）', calories: 250, protein: 4.0, fat: 0.5, carbs: 55.0),
      MealItem(name: '玄米（茶碗1杯）', calories: 240, protein: 4.5, fat: 1.5, carbs: 51.0),
      MealItem(name: 'オートミール（30g）', calories: 114, protein: 4.0, fat: 2.0, carbs: 19.0),
      MealItem(name: '食パン（6枚切り1枚）', calories: 160, protein: 6.0, fat: 2.5, carbs: 28.0),
      MealItem(name: '鶏むね肉（皮なし100g）', calories: 165, protein: 31.0, fat: 3.6, carbs: 0.0),
      MealItem(name: '鶏もも肉（皮なし100g）', calories: 190, protein: 25.0, fat: 9.0, carbs: 0.0),
      MealItem(name: '卵（1個）', calories: 80, protein: 6.5, fat: 5.5, carbs: 0.5),
      MealItem(name: '納豆（1パック）', calories: 100, protein: 8.0, fat: 5.0, carbs: 6.0),
      MealItem(name: '豆腐（絹150g）', calories: 90, protein: 7.0, fat: 5.0, carbs: 3.0),
      MealItem(name: 'ツナ缶（水煮1缶）', calories: 70, protein: 16.0, fat: 1.0, carbs: 0.0),
      MealItem(name: '牛乳（200ml）', calories: 134, protein: 6.8, fat: 7.6, carbs: 9.8),
      MealItem(name: 'ヨーグルト（無糖100g）', calories: 62, protein: 3.6, fat: 3.0, carbs: 4.7),
      MealItem(name: 'プロテイン（1杯）', calories: 120, protein: 23.0, fat: 2.0, carbs: 3.0),
      MealItem(name: 'バナナ（1本）', calories: 90, protein: 1.1, fat: 0.2, carbs: 23.0),
      MealItem(name: 'りんご（1個）', calories: 95, protein: 0.5, fat: 0.3, carbs: 25.0),
      MealItem(name: 'サラダ（野菜200g）', calories: 70, protein: 3.0, fat: 1.0, carbs: 12.0),
    ];

    return foods
        .where((f) => f.name.toLowerCase().contains(q))
        .take(30)
        .toList();
  }

  DateTime _parseTime(String? date, String? time) {
    if (time != null && date != null) {
      try {
        return DateTime.parse('$date $time');
      } catch (e) {
        // Fall through
      }
    }
    return DateTime.now();
  }
}
