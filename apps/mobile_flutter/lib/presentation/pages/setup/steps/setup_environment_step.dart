import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SetupEnvironmentStep extends StatelessWidget {
  final bool hasGym;
  final bool hasHome;
  final VoidCallback onToggleGym;
  final VoidCallback onToggleHome;
  final List<String> equipment;
  final Set<String> selectedEquipment;
  final ValueChanged<String> onToggleEquipment;

  const SetupEnvironmentStep({
    super.key,
    required this.hasGym,
    required this.hasHome,
    required this.onToggleGym,
    required this.onToggleHome,
    required this.equipment,
    required this.selectedEquipment,
    required this.onToggleEquipment,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'トレーニング環境',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '利用可能な場所と器具を選択してください',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            '場所',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ToggleCard(
                  label: 'ジム',
                  icon: Icons.fitness_center,
                  isSelected: hasGym,
                  onTap: onToggleGym,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ToggleCard(
                  label: '自宅',
                  icon: Icons.home,
                  isSelected: hasHome,
                  onTap: onToggleHome,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            '使用可能な器具',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: equipment.map((item) {
              final isSelected = selectedEquipment.contains(item);
              return GestureDetector(
                onTap: () => onToggleEquipment(item),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.greenPrimary : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.greenPrimary : AppColors.border,
                    ),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToggleCard({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? AppColors.greenPrimary : AppColors.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected ? AppColors.greenPrimary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


