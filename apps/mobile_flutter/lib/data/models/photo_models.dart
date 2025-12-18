class PhotoItem {
  final String id;
  final String createdAt;
  final String imageUrl;

  PhotoItem({
    required this.id,
    required this.createdAt,
    required this.imageUrl,
  });

  factory PhotoItem.fromJson(Map<String, dynamic> json) {
    return PhotoItem(
      id: json['id']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }
}

class ListPhotosResponse {
  final List<PhotoItem> photos;

  ListPhotosResponse({required this.photos});

  factory ListPhotosResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['photos'] as List?) ?? [];
    return ListPhotosResponse(
      photos: list
          .whereType<Map<String, dynamic>>()
          .map(PhotoItem.fromJson)
          .toList(),
    );
  }
}

class UploadPhotoResponse {
  final PhotoItem photo;

  UploadPhotoResponse({required this.photo});

  factory UploadPhotoResponse.fromJson(Map<String, dynamic> json) {
    return UploadPhotoResponse(
      photo: PhotoItem.fromJson(json['photo'] as Map<String, dynamic>),
    );
  }
}


