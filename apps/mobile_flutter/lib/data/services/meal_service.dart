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
    // TODO: Integrate with food database API (e.g., FatSecret, USDA)
    // For now, return empty list
    return [];
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
