import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../widgets/common/app_text_field.dart';

class SetupBodyStep extends StatelessWidget {
  final String selectedSex;
  final ValueChanged<String> onSexChanged;
  final TextEditingController ageController;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final int mealsPerDay;
  final ValueChanged<int> onMealsPerDayChanged;

  const SetupBodyStep({
    super.key,
    required this.selectedSex,
    required this.onSexChanged,
    required this.ageController,
    required this.heightController,
    required this.weightController,
    required this.mealsPerDay,
    required this.onMealsPerDayChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '身体情報',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'AIアドバイスの精度向上に使用します',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Sex selection
          const Text(
            '性別',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SexButton(
                  value: 'male',
                  label: '男性',
                  icon: Icons.male,
                  isSelected: selectedSex == 'male',
                  onTap: () => onSexChanged('male'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SexButton(
                  value: 'female',
                  label: '女性',
                  icon: Icons.female,
                  isSelected: selectedSex == 'female',
                  onTap: () => onSexChanged('female'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          AppNumberField(
            controller: ageController,
            label: '年齢',
            hint: '25',
            unit: '歳',
            allowDecimal: false,
          ),
          const SizedBox(height: 20),
          AppNumberField(
            controller: heightController,
            label: '身長',
            hint: '170',
            unit: 'cm',
            allowDecimal: false,
          ),
          const SizedBox(height: 20),
          AppNumberField(
            controller: weightController,
            label: '体重',
            hint: '70.0',
            unit: 'kg',
          ),
          const SizedBox(height: 32),
          const Text(
            '1日の食事回数',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              final count = index + 2;
              final isSelected = mealsPerDay == count;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onMealsPerDayChanged(count),
                  child: Container(
                    margin: EdgeInsets.only(right: index < 4 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.greenPrimary : AppColors.bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? AppColors.greenPrimary : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _SexButton extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _SexButton({
    required this.value,
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
        padding: const EdgeInsets.symmetric(vertical: 16),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.greenPrimary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
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


