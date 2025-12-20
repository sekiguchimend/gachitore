import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';

class SupportService {
  final ApiClient _apiClient;

  SupportService({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  Future<void> sendContact({
    required String subject,
    required String message,
    String? platform,
    String? appVersion,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      await _apiClient.post(
        '/support/contact',
        data: {
          'subject': subject,
          'message': message,
          if (platform != null) 'platform': platform,
          if (appVersion != null) 'app_version': appVersion,
          if (deviceInfo != null) 'device_info': deviceInfo,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}


