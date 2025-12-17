import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../models/workout_models.dart';

class WorkoutService {
  final ApiClient _apiClient;

  WorkoutService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  /// Log a workout session
  Future<LogWorkoutResponse> logWorkout(LogWorkoutRequest request) async {
    try {
      final response = await _apiClient.post(
        '/log/workout',
        data: request.toJson(),
      );

      return LogWorkoutResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get all exercises (from database)
  Future<List<Exercise>> getExercises({String? muscleGroup}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (muscleGroup != null && muscleGroup.isNotEmpty) {
        queryParams['muscle_group'] = muscleGroup;
      }

      final response = await _apiClient.get(
        '/exercises',
        queryParameters: queryParams,
      );

      return (response.data as List).map((e) {
        return Exercise(
          id: e['id'] ?? '',
          name: e['name'] ?? '',
          muscleGroup: e['primary_muscle'] ?? '',  // 単数形に修正
          e1rm: 0,
          lastWeight: 0,
          lastReps: 0,
          trend: 0,
        );
      }).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get exercises with user's performance data
  Future<List<Exercise>> getExercisesWithStats() async {
    try {
      final response = await _apiClient.get('/exercises/stats');
      return (response.data as List).map((e) => Exercise.fromJson(e)).toList();
    } on DioException catch (e) {
      // Fallback to basic exercise list if API not available
      return getExercises();
    }
  }

  /// Get workout history
  Future<List<WorkoutSession>> getWorkoutHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _apiClient.get(
        '/workouts',
        queryParameters: {
          'limit': limit,
          'offset': offset,
        },
      );

      return (response.data as List).map((w) {
        return WorkoutSession(
          id: w['id'],
          date: DateTime.parse(w['date']),
          name: w['name'] ?? '未命名のワークアウト',
          exerciseCount: w['exercise_count'] ?? 0,
          duration: Duration(minutes: w['duration_minutes'] ?? 0),
          totalVolume: (w['total_volume'] ?? 0).toDouble(),
        );
      }).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get workout details
  Future<Map<String, dynamic>> getWorkoutDetails(String workoutId) async {
    try {
      final response = await _apiClient.get('/workouts/$workoutId');
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Calculate e1RM using Epley formula
  double calculateE1rm(double weight, int reps) {
    if (reps == 1) return weight;
    if (reps <= 0 || weight <= 0) return 0;
    return weight * (1 + reps / 30);
  }
}
