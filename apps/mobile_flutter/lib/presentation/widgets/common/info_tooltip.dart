import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// iマークのツールチップウィジェット
/// タップすると説明文が表示される
class InfoTooltip extends StatelessWidget {
  final String explanation;
  final double size;

  const InfoTooltip({
    super.key,
    required this.explanation,
    this.size = 24,
  });

  void _showExplanation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Text(
          explanation,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '閉じる',
              style: TextStyle(
                color: AppColors.greenPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 見た目は小さく、タップ領域は広めに確保
    final hitSize = size < 44 ? 44.0 : size;

    return SizedBox(
      width: hitSize,
      height: hitSize,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showExplanation(context),
          borderRadius: BorderRadius.circular(hitSize / 2),
          child: Center(
            child: Icon(
              // アイコン自体が丸枠を持つため、外側に枠を描くと二重丸に見えてしまう
              Icons.info_outline,
              size: size,
              color: AppColors.textTertiary,
            ),
          ),
        ),
      ),
    );
  }
}
