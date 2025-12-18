import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../models/ai_models.dart';

class AiService {
  final ApiClient _apiClient;

  AiService({required ApiClient apiClient}) : _apiClient = apiClient;

  /// Ask AI coach a question
  Future<AskResponse> askAi(AskRequest request) async {
    try {
      final response = await _apiClient.post(
        '/ai/ask',
        data: request.toJson(),
      );

      return AskResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get today's workout plan from AI
  Future<PlanTodayResponse> getPlanToday(PlanTodayRequest request) async {
    try {
      final response = await _apiClient.post(
        '/ai/plan/today',
        data: request.toJson(),
      );

      return PlanTodayResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get AI conversation history
  Future<AiHistoryResponse> getHistory() async {
    try {
      final response = await _apiClient.get('/ai/history');

      return AiHistoryResponse.fromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Get unread inbox messages (bot notifications)
  Future<List<AiInboxMessage>> getInboxMessages() async {
    try {
      final response = await _apiClient.get('/ai/inbox');
      final list = response.data as List;
      return list.map((m) => AiInboxMessage.fromJson(m)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Quick actions - predefined prompts
  Future<AskResponse> getTodayMenu() async {
    return askAi(AskRequest(
      message: '今日のトレーニングメニューを教えて',
    ));
  }

  Future<AskResponse> getMealSuggestion() async {
    return askAi(AskRequest(
      message: '今日の残りのPFCバランスを考えた食事を提案して',
    ));
  }

  Future<AskResponse> getProgressAnalysis() async {
    return askAi(AskRequest(
      message: '最近の進捗を分析して、停滞していないか診断して',
    ));
  }

  Future<AskResponse> getFormAdvice(String exerciseName) async {
    return askAi(AskRequest(
      message: '$exerciseNameの正しいフォームとコツを教えて',
    ));
  }
}
