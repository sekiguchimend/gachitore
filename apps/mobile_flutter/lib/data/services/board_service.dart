import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../models/board_models.dart';
import '../models/meal_models.dart';

/// 掲示板サービス
class BoardService {
  final ApiClient _apiClient;
  ImagePicker? _picker;

  BoardService({required ApiClient apiClient}) : _apiClient = apiClient;

  ImagePicker get _imagePicker => _picker ??= ImagePicker();

  /// 投稿一覧を取得（新しい順）
  Future<ListPostsResponse> listPosts({int limit = 50, int offset = 0}) async {
    try {
      final res = await _apiClient.get(
        '/posts',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return ListPostsResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// テキストのみの投稿を作成
  Future<CreatePostResponse> createTextPost(String content) async {
    try {
      final form = FormData.fromMap({
        'content': content,
      });

      final res = await _apiClient.post(
        '/posts',
        data: form,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      return CreatePostResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// 画像付きの投稿を作成
  Future<CreatePostResponse> createPostWithImage(String content, XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final filename = imageFile.name.isNotEmpty ? imageFile.name : 'image.jpg';

      final form = FormData.fromMap({
        'content': content,
        'image': MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      });

      final res = await _apiClient.post(
        '/posts',
        data: form,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      return CreatePostResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// ギャラリーから画像を選択
  Future<XFile?> pickImageFromGallery() async {
    return await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
  }

  /// カメラで撮影
  Future<XFile?> takePhoto() async {
    return await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
  }

  /// 投稿を削除
  Future<void> deletePost(String postId) async {
    try {
      await _apiClient.delete('/posts/$postId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ==================== いいね関連 ====================

  /// 投稿にいいねをトグル（追加/削除）
  Future<LikeResponse> togglePostLike(String postId) async {
    try {
      final res = await _apiClient.post('/posts/$postId/like');
      return LikeResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// コメントにいいねをトグル（追加/削除）
  Future<LikeResponse> toggleCommentLike(String commentId) async {
    try {
      final res = await _apiClient.post('/comments/$commentId/like');
      return LikeResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // ==================== コメント関連 ====================

  /// 投稿のコメント一覧を取得
  Future<ListCommentsResponse> listComments(String postId, {int limit = 50, int offset = 0}) async {
    try {
      final res = await _apiClient.get(
        '/posts/$postId/comments',
        queryParameters: {'limit': limit, 'offset': offset},
      );
      return ListCommentsResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// コメントを作成
  Future<CreateCommentResponse> createComment(
    String postId,
    String content, {
    String? replyToUserId,
  }) async {
    try {
      final data = <String, dynamic>{
        'content': content,
      };
      if (replyToUserId != null) {
        data['reply_to_user_id'] = replyToUserId;
      }

      final res = await _apiClient.post(
        '/posts/$postId/comments',
        data: data,
      );
      return CreateCommentResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// コメントを削除
  Future<void> deleteComment(String commentId) async {
    try {
      await _apiClient.delete('/comments/$commentId');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// ユーザーのワークアウト履歴を取得（日付とボリューム）
  Future<WorkoutDatesWithVolume> getUserWorkoutDates(String userId) async {
    try {
      final res = await _apiClient.get('/users/$userId/workout-dates');
      return WorkoutDatesWithVolume.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// ユーザーの今日の食事を取得（プロフィール表示用）
  Future<List<MealEntry>> getUserMealsToday(String userId) async {
    try {
      final res = await _apiClient.get('/users/$userId/meals/today');
      final meals = (res.data as List?)
              ?.map((m) => MealEntry.fromJson(_convertMealItemsKey(m as Map<String, dynamic>)))
              .toList() ??
          [];
      return meals;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// APIレスポンスのmeal_itemsをitemsに変換
  Map<String, dynamic> _convertMealItemsKey(Map<String, dynamic> json) {
    if (json.containsKey('meal_items')) {
      json['items'] = json['meal_items'];
    }
    return json;
  }
}

