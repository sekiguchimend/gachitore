part of 'food_page.dart';

extension _FoodPagePhotoAddSheet on _FoodPageState {
  /// 写真から追加シート
  void _showPhotoAddSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
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
                  '写真から追加',
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
            const SizedBox(height: 8),
            const Text(
              'まず写真を選択し、内容はあとから手動で入力します',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            _buildAddMealOption(
              sheetContext,
              Icons.camera_alt_outlined,
              '撮影する',
              'カメラを起動します',
              () => _pickMealPhotoAndContinue(source: _MealPhotoSource.camera),
            ),
            _buildAddMealOption(
              sheetContext,
              Icons.photo_library_outlined,
              'ギャラリーから選ぶ',
              '端末の写真を選択します',
              () => _pickMealPhotoAndContinue(source: _MealPhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickMealPhotoAndContinue({
    required _MealPhotoSource source,
  }) async {
    // 既存デザインを崩さないため、ここでは簡易SnackBarで状態を出す
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('写真をアップロード中...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final photoService = ref.read(photoServiceProvider);
      final uploaded = await (source == _MealPhotoSource.camera
          ? photoService.takeAndUploadPhoto()
          : photoService.pickFromGalleryAndUploadPhoto());

      if (uploaded == null) return; // user cancelled

      // 写真URLを保持して、手動入力シートへ引き継ぐ
      if (!mounted) return;
      _showManualInputSheet(photoUrl: uploaded.photo.imageUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('写真の処理に失敗しました: $e')),
      );
    }
  }
}

enum _MealPhotoSource { camera, gallery }


