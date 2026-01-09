import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/board_models.dart';

class BoardPage extends ConsumerStatefulWidget {
  const BoardPage({super.key});

  @override
  ConsumerState<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends ConsumerState<BoardPage> {
  bool _loading = true;
  String? _error;
  List<BoardPost> _posts = [];
  String? _currentUserId;

  // Compose
  final _composeController = TextEditingController();
  final _composeFocusNode = FocusNode();
  XFile? _selectedImage;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _load();
    _composeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _composeController.dispose();
    _composeFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final authService = ref.read(authServiceProvider);
    final userId = await authService.currentUserId;
    if (mounted) {
      setState(() => _currentUserId = userId);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final boardService = ref.read(boardServiceProvider);
      final res = await boardService.listPosts(limit: 100);
      if (!mounted) return;
      setState(() {
        _posts = res.posts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file != null && mounted) {
      setState(() => _selectedImage = file);
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
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
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.greenPrimary),
              title: const Text(
                'ライブラリから選択',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppColors.greenPrimary),
              title: const Text(
                '写真を撮る',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _submitPost() async {
    final content = _composeController.text.trim();
    if (content.isEmpty || _posting) return;

    if (content.length > 1000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('1000文字以内で入力してください'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _posting = true);
    final success = await _createPost(content, _selectedImage);
    if (!mounted) return;

    if (success) {
      _composeController.clear();
      setState(() => _selectedImage = null);
      _composeFocusNode.unfocus();
    }
    setState(() => _posting = false);
  }

  Future<bool> _createPost(String content, XFile? image) async {
    try {
      final boardService = ref.read(boardServiceProvider);
      CreatePostResponse res;
      if (image != null) {
        res = await boardService.createPostWithImage(content, image);
      } else {
        res = await boardService.createTextPost(content);
      }
      if (!mounted) return false;
      setState(() {
        _posts = [res.post, ..._posts];
      });
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('投稿に失敗しました: $e'),
          backgroundColor: AppColors.error,
        ),
      );
      return false;
    }
  }

  Future<void> _deletePost(BoardPost post) async {
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
                '投稿を削除',
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
      await boardService.deletePost(post.id);
      if (!mounted) return;
      setState(() {
        _posts.removeWhere((p) => p.id == post.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('投稿を削除しました'),
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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.greenPrimary,
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),
              // Compose box at top
              SliverToBoxAdapter(
                child: _buildComposeBox(),
              ),
              // Content
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Center(
              child: Text(
                '掲示板',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: IconButton(
                onPressed: _loading ? null : _load,
                icon: Icon(
                  Icons.refresh,
                  color: _loading ? AppColors.textTertiary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposeBox() {
    final hasText = _composeController.text.trim().isNotEmpty;
    final canPost = hasText && !_posting;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.greenPrimary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: AppColors.greenPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          // Text area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _composeController,
                  focusNode: _composeFocusNode,
                  maxLines: null,
                  minLines: 2,
                  maxLength: 1000,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'いまどうしてる？',
                    hintStyle: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textTertiary,
                    ),
                    filled: true,
                    fillColor: AppColors.bgSub,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.greenPrimary),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    counterText: '',
                  ),
                ),
                // Selected image preview
                if (_selectedImage != null) ...[
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_selectedImage!.path),
                          width: double.infinity,
                          height: 150,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                // Action row
                Row(
                  children: [
                    GestureDetector(
                      onTap: _showImagePicker,
                      child: const Icon(Icons.image_outlined, color: AppColors.greenPrimary, size: 20),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _pickImage(ImageSource.camera),
                      child: const Icon(Icons.camera_alt_outlined, color: AppColors.greenPrimary, size: 20),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: canPost ? _submitPost : null,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: canPost ? AppColors.greenPrimary : AppColors.greenMuted,
                          shape: BoxShape.circle,
                        ),
                        child: _posting
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.send,
                                color: canPost ? Colors.white : Colors.white70,
                                size: 16,
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
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AppColors.greenPrimary),
        ),
      );
    }
    if (_error != null) {
      return SliverFillRemaining(
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
                  onPressed: _load,
                  child: const Text('再読み込み'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (_posts.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.chat_bubble_outline, color: AppColors.textTertiary, size: 48),
                SizedBox(height: 16),
                Text(
                  'まだ投稿がありません',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '最初の投稿をしてみましょう',
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

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final post = _posts[index];
          final isOwn = post.userId == _currentUserId;
          return Column(
            children: [
              _PostTile(
                post: post,
                isOwn: isOwn,
                onDelete: isOwn ? () => _deletePost(post) : null,
                onImageTap: post.imageUrl != null ? () => _showImageViewer(post.imageUrl!) : null,
              ),
              Container(height: 1, color: AppColors.border),
            ],
          );
        },
        childCount: _posts.length,
      ),
    );
  }

  void _showImageViewer(String imageUrl) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) => _ImageViewerPage(
          imageUrl: imageUrl,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

// Twitter-like post tile
class _PostTile extends StatelessWidget {
  final BoardPost post;
  final bool isOwn;
  final VoidCallback? onDelete;
  final VoidCallback? onImageTap;

  const _PostTile({
    required this.post,
    required this.isOwn,
    this.onDelete,
    this.onImageTap,
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

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: isOwn ? onDelete : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.greenPrimary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  post.displayName.isNotEmpty ? post.displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.greenPrimary,
                  ),
                ),
              ),
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
                      Flexible(
                        child: Text(
                          post.displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '· ${_formatDate(post.createdAt)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      if (isOwn) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: onDelete,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.more_horiz,
                              size: 18,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Post content
                  Text(
                    post.content,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                  // Image
                  if (post.imageUrl != null) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: onImageTap,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          post.imageUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 180,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 180,
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
                          errorBuilder: (_, __, ___) => Container(
                            height: 180,
                            decoration: BoxDecoration(
                              color: AppColors.bgSub,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(Icons.broken_image, color: AppColors.textTertiary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Full-screen image viewer
class _ImageViewerPage extends StatelessWidget {
  final String imageUrl;

  const _ImageViewerPage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.greenPrimary,
                ),
              );
            },
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}
