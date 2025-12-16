import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../models/dashboard_models.dart';

class DashboardService {
  final ApiClient _apiClient;

  DashboardService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Get dashboard data for today or specific date
  Future<DashboardResponse> getDashboard({DateTime? date}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (date != null) {
        queryParams['date'] = date.toIso8601String().split('T')[0];
      }

      final response = await _apiClient.get(
        '/dashboard/today',
        queryParameters: queryParams,
      );

      return DashboardResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Log body metrics (weight, bodyfat, etc.)
  Future<void> logBodyMetrics({
    required DateTime date,
    double? weightKg,
    double? bodyfatPct,
    double? sleepHours,
    int? steps,
  }) async {
    try {
      await _apiClient.post(
        '/log/metrics',
        data: {
          'date': date.toIso8601String().split('T')[0],
          if (weightKg != null) 'weight_kg': weightKg,
          if (bodyfatPct != null) 'bodyfat_pct': bodyfatPct,
          if (sleepHours != null) 'sleep_hours': sleepHours,
          if (steps != null) 'steps': steps,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
