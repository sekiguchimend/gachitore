import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/board_models.dart';
import 'user_profile_page.dart';

/// 投稿詳細ページ（コメント機能付き）
class PostDetailPage extends ConsumerStatefulWidget {
  final BoardPost post;
  final void Function(BoardPost updatedPost)? onPostUpdated;

  const PostDetailPage({
    super.key,
    required this.post,
    this.onPostUpdated,
  });

  @override
  ConsumerState<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends ConsumerState<PostDetailPage> {
  late BoardPost _post;
  List<PostComment> _comments = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  String? _currentUserId;

  final _commentController = TextEditingController();
  final _commentFocusNode = FocusNode();
  bool _posting = false;

  // 返信先の情報
  String? _replyToUserId;
  String? _replyToDisplayName;

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadCurrentUser();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final authService = ref.read(authServiceProvider);
    final userId = await authService.currentUserId;
    if (mounted) {
      setState(() => _currentUserId = userId);
    }
  }

  Future<void> _loadComments() async {
    setState(() {
      _loading = true;
      _error = null;
      _hasMore = true;
    });
    try {
      final boardService = ref.read(boardServiceProvider);
      final res = await boardService.listComments(_post.id, limit: _pageSize, offset: 0);
      if (!mounted) return;
      setState(() {
        _comments = res.comments;
        _loading = false;
        _hasMore = res.comments.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadMoreComments() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final boardService = ref.read(boardServiceProvider);
      final res = await boardService.listComments(
        _post.id,
        limit: _pageSize,
        offset: _comments.length,
      );
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, ...res.comments];
        _loadingMore = false;
        _hasMore = res.comments.length >= _pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('読み込みに失敗しました: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _togglePostLike() async {
    try {
      final boardService = ref.read(boardServiceProvider);
      final res = await boardService.togglePostLike(_post.id);
      if (!mounted) return;
      setState(() {
        _post = _post.copyWith(
          isLiked: res.liked,
          likeCount: res.likeCount,
        );
      });
      widget.onPostUpdated?.call(_post);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('いいねに失敗しました: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _toggleCommentLike(PostComment comment) async {
    try {
      final boardService = ref.read(boardServiceProvider);
      final res = await boardService.toggleCommentLike(comment.id);
      if (!mounted) return;
      setState(() {
        final index = _comments.indexWhere((c) => c.id == comment.id);
        if (index != -1) {
          _comments[index] = _comments[index].copyWith(
            isLiked: res.liked,
            likeCount: res.likeCount,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('いいねに失敗しました: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _setReplyTo(PostComment comment) {
    setState(() {
      _replyToUserId = comment.userId;
      _replyToDisplayName = comment.displayName;
      _commentController.text = '@${comment.displayName} ';
    });
    _commentFocusNode.requestFocus();
    // カーソルを末尾に移動
    _commentController.selection = TextSelection.fromPosition(
      TextPosition(offset: _commentController.text.length),
    );
  }

  void _clearReply() {
    setState(() {
      _replyToUserId = null;
      _replyToDisplayName = null;
    });
    // @ユーザー名 を削除
    final text = _commentController.text;
    if (_replyToDisplayName != null && text.startsWith('@$_replyToDisplayName ')) {
      _commentController.text = text.substring('@$_replyToDisplayName '.length);
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _posting) return;

    if (content.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('500文字以内で入力してください'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _posting = true);
    try {
      final boardService = ref.read(boardServiceProvider);
      final res = await boardService.createComment(
        _post.id,
        content,
        replyToUserId: _replyToUserId,
      );
      if (!mounted) return;
      setState(() {
        _comments = [res.comment, ..._comments];
        _commentController.clear();
        _replyToUserId = null;
        _replyToDisplayName = null;
        _post = _post.copyWith(commentCount: _post.commentCount + 1);
      });
      widget.onPostUpdated?.call(_post);
      _commentFocusNode.unfocus();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('コメントに失敗しました: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _posting = false);
      }
    }
  }

  Future<void> _deleteComment(PostComment comment) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text(
                'コメントを削除',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              leading: const Icon(Icons.close, color: AppColors.textSecondary),
              title: const Text(
                'キャンセル',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => Navigator.pop(ctx, false),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      final boardService = ref.read(boardServiceProvider);
      await boardService.deleteComment(comment.id);
      if (!mounted) return;
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
        _post = _post.copyWith(commentCount: _post.commentCount - 1);
      });
      widget.onPostUpdated?.call(_post);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('コメントを削除しました'),
          backgroundColor: AppColors.greenPrimary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('削除に失敗しました: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgMain,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        ),
        title: const Text(
          '投稿',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadComments,
              color: AppColors.greenPrimary,
              child: CustomScrollView(
                slivers: [
                  // 投稿本文
                  SliverToBoxAdapter(
                    child: _buildPostSection(),
                  ),
                  // コメント一覧
                  _buildCommentsList(),
                ],
              ),
            ),
          ),
          // コメント入力欄
          _buildCommentInput(),
        ],
      ),
    );
  }

  Widget _buildPostSection() {
    final initial = _post.displayName.isNotEmpty ? _post.displayName[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ユーザー情報
          Row(
            children: [
              GestureDetector(
                onTap: () => _openUserProfile(),
                child: _buildAvatar(initial),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _post.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      _formatDate(_post.createdAt),
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 投稿内容
          Text(
            _post.content,
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
          // 画像
          if (_post.imageUrl != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _post.imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: AppColors.bgSub,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.greenPrimary,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
          // いいね・コメント数
          Row(
            children: [
              if (_post.likeCount > 0)
                Text(
                  '${_post.likeCount}件のいいね',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              if (_post.likeCount > 0 && _post.commentCount > 0)
                const Text(
                  '  •  ',
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              if (_post.commentCount > 0)
                Text(
                  '${_post.commentCount}件のコメント',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // アクションボタン
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // コメントボタン
                GestureDetector(
                  onTap: () => _commentFocusNode.requestFocus(),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline,
                        size: 20,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'コメント',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // いいねボタン
                GestureDetector(
                  onTap: _togglePostLike,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      Icon(
                        _post.isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: _post.isLiked ? AppColors.error : AppColors.textTertiary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'いいね',
                        style: TextStyle(
                          fontSize: 14,
                          color: _post.isLiked ? AppColors.error : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(String initial) {
    if (_post.avatarUrl != null && _post.avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          _post.avatarUrl!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialAvatar(initial),
        ),
      );
    }
    return _buildInitialAvatar(initial);
  }

  Widget _buildInitialAvatar(String initial) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.greenPrimary.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.greenPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildCommentsList() {
    if (_loading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(color: AppColors.greenPrimary),
        ),
      );
    }
    if (_error != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppColors.textTertiary, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'エラーが発生しました',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _loadComments,
                  child: const Text('再読み込み'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_comments.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, color: AppColors.textTertiary, size: 48),
                SizedBox(height: 16),
                Text(
                  'まだコメントがありません',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '最初のコメントをしてみましょう',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final itemCount = _comments.length + (_hasMore ? 1 : 0);

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index == _comments.length) {
            return _buildLoadMoreButton();
          }

          final comment = _comments[index];
          final isOwn = comment.userId == _currentUserId;
          return _CommentTile(
            comment: comment,
            isOwn: isOwn,
            onLikeTap: () => _toggleCommentLike(comment),
            onReplyTap: () => _setReplyTo(comment),
            onDelete: isOwn ? () => _deleteComment(comment) : null,
            onAvatarTap: () => _openCommentUserProfile(comment),
          );
        },
        childCount: itemCount,
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: _loadingMore
            ? const CircularProgressIndicator(
                color: AppColors.greenPrimary,
                strokeWidth: 2,
              )
            : TextButton(
                onPressed: _loadMoreComments,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  backgroundColor: AppColors.bgSub,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: AppColors.border),
                  ),
                ),
                child: const Text(
                  'もっと見る',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildCommentInput() {
    final hasText = _commentController.text.trim().isNotEmpty;
    final canPost = hasText && !_posting;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 返信先表示
          if (_replyToDisplayName != null)
            Container(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    '@$_replyToDisplayName に返信',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _clearReply,
                    child: const Icon(Icons.close, size: 16, color: AppColors.textTertiary),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  focusNode: _commentFocusNode,
                  maxLines: null,
                  minLines: 1,
                  maxLength: 500,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'コメントを入力...',
                    hintStyle: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.bgSub,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: canPost ? _submitComment : null,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: canPost ? AppColors.greenPrimary : AppColors.greenMuted,
                    shape: BoxShape.circle,
                  ),
                  child: _posting
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          Icons.send,
                          color: canPost ? Colors.white : Colors.white70,
                          size: 18,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      return DateFormat('yyyy/M/d H:mm').format(dt);
    } catch (_) {
      return '';
    }
  }

  void _openUserProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserProfilePage(
          userId: _post.userId,
          displayName: _post.displayName,
          avatarUrl: _post.avatarUrl,
        ),
      ),
    );
  }

  void _openCommentUserProfile(PostComment comment) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserProfilePage(
          userId: comment.userId,
          displayName: comment.displayName,
          avatarUrl: comment.avatarUrl,
        ),
      ),
    );
  }
}

/// コメントタイル
class _CommentTile extends StatelessWidget {
  final PostComment comment;
  final bool isOwn;
  final VoidCallback? onLikeTap;
  final VoidCallback? onReplyTap;
  final VoidCallback? onDelete;
  final VoidCallback? onAvatarTap;

  static const int _maxNameLength = 12;

  const _CommentTile({
    required this.comment,
    required this.isOwn,
    this.onLikeTap,
    this.onReplyTap,
    this.onDelete,
    this.onAvatarTap,
  });

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inMinutes < 1) {
        return '今';
      } else if (diff.inMinutes < 60) {
        return '${diff.inMinutes}分';
      } else if (diff.inHours < 24) {
        return '${diff.inHours}時間';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}日';
      } else if (dt.year == now.year) {
        return DateFormat('M月d日').format(dt);
      } else {
        return DateFormat('yyyy/M/d').format(dt);
      }
    } catch (_) {
      return '';
    }
  }

  String _truncateName(String name) {
    if (name.length <= _maxNameLength) return name;
    return '${name.substring(0, _maxNameLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _truncateName(comment.displayName);
    final initial = comment.displayName.isNotEmpty ? comment.displayName[0].toUpperCase() : '?';

    return InkWell(
      onLongPress: isOwn ? onDelete : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border.withOpacity(0.5))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            GestureDetector(
              onTap: onAvatarTap,
              child: _buildAvatar(initial),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· ${_formatDate(comment.createdAt)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const Spacer(),
                      if (isOwn)
                        GestureDetector(
                          onTap: onDelete,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.more_horiz,
                              size: 16,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Comment content (with reply mention highlighted)
                  _buildCommentContent(),
                  const SizedBox(height: 8),
                  // Action row
                  Row(
                    children: [
                      // 返信ボタン
                      GestureDetector(
                        onTap: onReplyTap,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.reply,
                                size: 16,
                                color: AppColors.textTertiary,
                              ),
                              SizedBox(width: 4),
                              Text(
                                '返信',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // いいねボタン
                      GestureDetector(
                        onTap: onLikeTap,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                comment.isLiked ? Icons.favorite : Icons.favorite_border,
                                size: 16,
                                color: comment.isLiked ? AppColors.error : AppColors.textTertiary,
                              ),
                              if (comment.likeCount > 0) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '${comment.likeCount}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: comment.isLiked ? AppColors.error : AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentContent() {
    final content = comment.content;
    
    // @ユーザー名 を検出してハイライト
    final mentionRegex = RegExp(r'@(\S+)');
    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in mentionRegex.allMatches(content)) {
      // マッチ前のテキスト
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        ));
      }
      // @メンション部分
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.greenPrimary,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
      ));
      lastEnd = match.end;
    }

    // 残りのテキスト
    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildAvatar(String initial) {
    if (comment.avatarUrl != null && comment.avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          comment.avatarUrl!,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildInitialAvatar(initial),
        ),
      );
    }
    return _buildInitialAvatar(initial);
  }

  Widget _buildInitialAvatar(String initial) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.greenPrimary.withOpacity(0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.greenPrimary,
          ),
        ),
      ),
    );
  }
}

