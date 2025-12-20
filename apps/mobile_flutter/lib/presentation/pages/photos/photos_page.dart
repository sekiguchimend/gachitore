import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cross_file/cross_file.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/photo_models.dart';
import 'photo_capture_page.dart';

class PhotosPage extends ConsumerStatefulWidget {
  const PhotosPage({super.key});

  @override
  ConsumerState<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends ConsumerState<PhotosPage> {
  static const int _maxPhotosPerUser = 100;

  bool _loading = true;
  bool _uploading = false;
  String? _error;
  List<PhotoItem> _photos = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final photoService = ref.read(photoServiceProvider);
      final res = await photoService.listPhotos(limit: _maxPhotosPerUser);
      if (!mounted) return;
      setState(() {
        _photos = res.photos;
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

  Future<void> _takePhoto() async {
    if (_uploading) return;
    if (_photos.length >= _maxPhotosPerUser) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真は1人100枚までです。不要な写真を削除してください。')),
      );
      return;
    }
    // Open camera page and take a picture
    final XFile? file = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PhotoCapturePage(),
      ),
    );

    if (file == null) return;

    setState(() => _uploading = true);
    try {
      final photoService = ref.read(photoServiceProvider);
      final res = await photoService.uploadPhotoFile(file);
      if (!mounted) return;
      setState(() {
        _photos = [res.photo, ..._photos];
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reachedLimit = _photos.length >= _maxPhotosPerUser;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: (_uploading || reachedLimit) ? null : _takePhoto,
        backgroundColor: AppColors.greenPrimary,
        child: _uploading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.textPrimary,
                ),
              )
            : const Icon(Icons.camera_alt_outlined, color: AppColors.textPrimary),
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
                '写真',
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
                icon: const Icon(
                  Icons.refresh,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.greenPrimary),
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_photos.isEmpty) {
      return const Center(
        child: Text(
          'まだ写真がありません。\n右下のボタンから撮影して保存できます。',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.greenPrimary,
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: _photos.length,
        itemBuilder: (context, index) {
          final p = _photos[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: AppColors.bgCard,
              child: GestureDetector(
                onTap: () => _openPhotoModal(p),
                child: Image.network(
                  p.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, error, __) {
                    debugPrint('[Photos] image load failed: ${p.imageUrl} / $error');
                    return const Center(
                      child: Icon(Icons.broken_image, color: AppColors.textTertiary),
                    );
                  },
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.greenPrimary,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _openPhotoModal(PhotoItem photo) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black,
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.network(
                      photo.imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 240,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.greenPrimary,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, error, __) {
                        debugPrint('[Photos] modal image load failed: ${photo.imageUrl} / $error');
                        return const SizedBox(
                          height: 240,
                          child: Center(
                            child: Icon(Icons.broken_image, color: AppColors.textTertiary),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  onPressed: () => _confirmDelete(dialogContext, photo),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext dialogContext, PhotoItem photo) {
    showDialog(
      context: dialogContext,
      builder: (confirmContext) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text(
          '写真を削除',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'この写真を削除しますか？\nこの操作は取り消せません。',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmContext),
            child: const Text(
              'キャンセル',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(confirmContext);
              Navigator.pop(dialogContext);
              await _deletePhoto(photo);
            },
            child: const Text(
              '削除',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deletePhoto(PhotoItem photo) async {
    try {
      final photoService = ref.read(photoServiceProvider);
      await photoService.deletePhoto(photo.id);
      if (!mounted) return;
      setState(() {
        _photos.removeWhere((p) => p.id == photo.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真を削除しました')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('削除に失敗しました: $e')),
      );
    }
  }
}


