/// 掲示板の投稿モデル
class BoardPost {
  final String id;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String content;
  final String? imageUrl;
  final String? thumbnailUrl;
  final String createdAt;

  const BoardPost({
    required this.id,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.content,
    this.imageUrl,
    this.thumbnailUrl,
    required this.createdAt,
  });

  factory BoardPost.fromJson(Map<String, dynamic> json) {
    return BoardPost(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '匿名',
      avatarUrl: json['avatar_url']?.toString(),
      content: json['content']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }
}

class ListPostsResponse {
  final List<BoardPost> posts;

  ListPostsResponse({required this.posts});

  factory ListPostsResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['posts'] as List?) ?? [];
    return ListPostsResponse(
      posts: list
          .whereType<Map<String, dynamic>>()
          .map(BoardPost.fromJson)
          .toList(),
    );
  }
}

class CreatePostResponse {
  final BoardPost post;

  CreatePostResponse({required this.post});

  factory CreatePostResponse.fromJson(Map<String, dynamic> json) {
    return CreatePostResponse(
      post: BoardPost.fromJson(json['post'] as Map<String, dynamic>),
    );
  }
}

