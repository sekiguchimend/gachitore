import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class HomeTopHeader extends StatelessWidget {
  final VoidCallback onSettingsTap;

  const HomeTopHeader({
    super.key,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Center(
              child: Text(
                'ガチトレ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Positioned(
              left: 0,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.greenPrimary.withValues(alpha:0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: AppColors.greenPrimary,
                  size: 20,
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: IconButton(
                onPressed: onSettingsTap,
                icon: const Icon(
                  Icons.settings_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


