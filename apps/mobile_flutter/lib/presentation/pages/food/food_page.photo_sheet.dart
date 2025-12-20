part of 'food_page.dart';

extension _FoodPagePhotoSheet on _FoodPageState {
  void _showPhotoAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.of(sheetContext).padding.bottom;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '写真を追加',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildAddMealOption(
                  sheetContext,
                  Icons.camera_alt_outlined,
                  '写真を撮る',
                  'カメラで撮影してアップロード',
                  () => _takeAndUploadPhoto(),
                ),
                _buildAddMealOption(
                  sheetContext,
                  Icons.photo_library_outlined,
                  'ギャラリーから選ぶ',
                  '端末の写真から選択してアップロード',
                  () => _pickFromGalleryAndUploadPhoto(),
                ),
                _buildAddMealOption(
                  sheetContext,
                  Icons.photo_outlined,
                  '写真一覧を見る',
                  'アップロード済みの写真を確認',
                  () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PhotosPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _takeAndUploadPhoto() async {
    final photoService = ref.read(photoServiceProvider);
    await _uploadWithBlockingDialog(() => photoService.takeAndUploadPhoto());
  }

  Future<void> _pickFromGalleryAndUploadPhoto() async {
    final photoService = ref.read(photoServiceProvider);
    await _uploadWithBlockingDialog(
      () => photoService.pickFromGalleryAndUploadPhoto(),
    );
  }

  Future<void> _uploadWithBlockingDialog(
    Future<dynamic> Function() uploadFn,
  ) async {
    if (!mounted) return;

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.greenPrimary),
      ),
    );

    try {
      final res = await uploadFn();
      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop(); // close progress
      if (res == null) return; // user cancelled

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('写真をアップロードしました')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // close progress
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('アップロードに失敗しました: $e')),
      );
    }
  }
}


