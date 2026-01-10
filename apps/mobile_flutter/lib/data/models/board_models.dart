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
  final int likeCount;
  final int commentCount;
  final bool isLiked;

  const BoardPost({
    required this.id,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.content,
    this.imageUrl,
    this.thumbnailUrl,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
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
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
    );
  }

  BoardPost copyWith({
    int? likeCount,
    int? commentCount,
    bool? isLiked,
  }) {
    return BoardPost(
      id: id,
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      content: content,
      imageUrl: imageUrl,
      thumbnailUrl: thumbnailUrl,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLiked: isLiked ?? this.isLiked,
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

/// コメントモデル
class PostComment {
  final String id;
  final String postId;
  final String userId;
  final String displayName;
  final String? avatarUrl;
  final String content;
  final String? replyToUserId;
  final String? replyToDisplayName;
  final String createdAt;
  final int likeCount;
  final bool isLiked;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
    required this.content,
    this.replyToUserId,
    this.replyToDisplayName,
    required this.createdAt,
    this.likeCount = 0,
    this.isLiked = false,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: json['id']?.toString() ?? '',
      postId: json['post_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '匿名',
      avatarUrl: json['avatar_url']?.toString(),
      content: json['content']?.toString() ?? '',
      replyToUserId: json['reply_to_user_id']?.toString(),
      replyToDisplayName: json['reply_to_display_name']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      likeCount: json['like_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
    );
  }

  PostComment copyWith({
    int? likeCount,
    bool? isLiked,
  }) {
    return PostComment(
      id: id,
      postId: postId,
      userId: userId,
      displayName: displayName,
      avatarUrl: avatarUrl,
      content: content,
      replyToUserId: replyToUserId,
      replyToDisplayName: replyToDisplayName,
      createdAt: createdAt,
      likeCount: likeCount ?? this.likeCount,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

/// コメント一覧レスポンス
class ListCommentsResponse {
  final List<PostComment> comments;

  ListCommentsResponse({required this.comments});

  factory ListCommentsResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['comments'] as List?) ?? [];
    return ListCommentsResponse(
      comments: list
          .whereType<Map<String, dynamic>>()
          .map(PostComment.fromJson)
          .toList(),
    );
  }
}

/// コメント作成レスポンス
class CreateCommentResponse {
  final PostComment comment;

  CreateCommentResponse({required this.comment});

  factory CreateCommentResponse.fromJson(Map<String, dynamic> json) {
    return CreateCommentResponse(
      comment: PostComment.fromJson(json['comment'] as Map<String, dynamic>),
    );
  }
}

/// いいねレスポンス
class LikeResponse {
  final bool liked;
  final int likeCount;

  LikeResponse({required this.liked, required this.likeCount});

  factory LikeResponse.fromJson(Map<String, dynamic> json) {
    return LikeResponse(
      liked: json['liked'] as bool? ?? false,
      likeCount: json['like_count'] as int? ?? 0,
    );
  }
}

/// ワークアウト日付とボリューム
class WorkoutDateVolume {
  final String date;
  final double volume;

  WorkoutDateVolume({required this.date, required this.volume});

  factory WorkoutDateVolume.fromJson(Map<String, dynamic> json) {
    return WorkoutDateVolume(
      date: json['date']?.toString() ?? '',
      volume: (json['volume'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// ワークアウト日付一覧（ボリューム付き）
class WorkoutDatesWithVolume {
  final List<String> dates;
  final List<WorkoutDateVolume> workouts;

  WorkoutDatesWithVolume({required this.dates, required this.workouts});

  factory WorkoutDatesWithVolume.fromJson(Map<String, dynamic> json) {
    final datesList = (json['dates'] as List?)?.map((d) => d.toString()).toList() ?? [];
    final workoutsList = (json['workouts'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(WorkoutDateVolume.fromJson)
            .toList() ??
        [];
    return WorkoutDatesWithVolume(dates: datesList, workouts: workoutsList);
  }

  /// 日付からボリュームを取得するマップを生成
  Map<String, double> toVolumeMap() {
    final map = <String, double>{};
    for (final w in workouts) {
      map[w.date] = w.volume;
    }
    return map;
  }
}

