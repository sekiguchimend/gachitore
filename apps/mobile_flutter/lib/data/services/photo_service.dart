import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api/api_client.dart';
import '../models/photo_models.dart';

class PhotoService {
  final ApiClient _apiClient;
  final ImagePicker _picker = ImagePicker();

  PhotoService({required ApiClient apiClient}) : _apiClient = apiClient;

  Future<ListPhotosResponse> listPhotos({int limit = 60}) async {
    try {
      final res = await _apiClient.get(
        '/photos',
        queryParameters: {'limit': limit},
      );
      return ListPhotosResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// Open camera and upload the taken photo
  Future<UploadPhotoResponse?> takeAndUploadPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 92,
    );
    if (picked == null) return null;

    return uploadPhotoFile(picked);
  }

  /// Pick from gallery and upload
  Future<UploadPhotoResponse?> pickFromGalleryAndUploadPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null) return null;

    return uploadPhotoFile(picked);
  }

  Future<UploadPhotoResponse> uploadPhotoFile(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final filename = file.name.isNotEmpty ? file.name : 'photo.jpg';

      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      });

      final res = await _apiClient.post(
        '/photos',
        data: form,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );

      return UploadPhotoResponse.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}


