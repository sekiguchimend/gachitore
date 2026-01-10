import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../setup_models.dart';

class SetupLevelStep extends StatelessWidget {
  final List<SetupLevel> levels;
  final String? selectedLevelId;
  final ValueChanged<String> onSelect;

  const SetupLevelStep({
    super.key,
    required this.levels,
    required this.selectedLevelId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'トレーニングレベル',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '現在のトレーニング経験を教えてください',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          ...levels.map((l) => _LevelCard(
                id: l.id,
                label: l.label,
                desc: l.desc,
                isSelected: selectedLevelId == l.id,
                onTap: () => onSelect(l.id),
              )),
        ],
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  final String id;
  final String label;
  final String desc;
  final bool isSelected;
  final VoidCallback onTap;

  const _LevelCard({
    required this.id,
    required this.label,
    required this.desc,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.greenPrimary.withValues(alpha:0.15) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.greenPrimary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.greenPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: AppColors.greenPrimary,
              ),
          ],
        ),
      ),
    );
  }
}


