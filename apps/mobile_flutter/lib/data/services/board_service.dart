import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../models/board_models.dart';

/// 掲示板サービス
class BoardService {
  final ApiClient _apiClient;
  final ImagePicker _picker = ImagePicker();

  BoardService({required ApiClient apiClient}) : _apiClient = apiClient;

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
    return await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
  }

  /// カメラで撮影
  Future<XFile?> takePhoto() async {
    return await _picker.pickImage(
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

  /// ユーザーのワークアウト履歴日付のみを取得（N+1回避のため必要なデータのみ）
  Future<List<String>> getUserWorkoutDates(String userId) async {
    try {
      final res = await _apiClient.get('/users/$userId/workout-dates');
      final dates = (res.data['dates'] as List?)?.map((d) => d.toString()).toList() ?? [];
      return dates;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}

