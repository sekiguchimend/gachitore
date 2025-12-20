import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/dashboard_models.dart';

class DailySummaryStrip extends StatelessWidget {
  final bool isLoading;
  final DashboardResponse? dashboard;

  const DailySummaryStrip({
    super.key,
    required this.isLoading,
    required this.dashboard,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        height: 60,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.greenPrimary,
          ),
        ),
      );
    }

    final weight = dashboard?.bodyMetrics?.weightKg?.toStringAsFixed(1) ?? '--';
    final calories = dashboard?.nutrition?.calories.toString() ?? '0';
    final protein = dashboard?.nutrition?.proteinG.round().toString() ?? '0';
    final workoutStatus = dashboard?.tasks.workoutLogged == true ? '完了' : '未完了';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _MiniStatCard(
              icon: Icons.monitor_weight_outlined,
              label: '体重',
              value: weight,
              unit: 'kg',
            ),
            const SizedBox(width: 8),
            _MiniStatCard(
              icon: Icons.local_fire_department_outlined,
              label: 'カロリー',
              value: calories,
              unit: 'kcal',
              color: AppColors.warning,
            ),
            const SizedBox(width: 8),
            _MiniStatCard(
              icon: Icons.egg_outlined,
              label: 'タンパク質',
              value: protein,
              unit: 'g',
              color: AppColors.info,
            ),
            const SizedBox(width: 8),
            _MiniStatCard(
              icon: Icons.fitness_center,
              label: 'トレーニング',
              value: workoutStatus,
              color: dashboard?.tasks.workoutLogged == true
                  ? AppColors.success
                  : AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? unit;
  final Color? color;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.unit,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: color ?? AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
              Row(
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: color ?? AppColors.textPrimary,
                    ),
                  ),
                  if (unit != null) ...[
                    const SizedBox(width: 2),
                    Text(
                      unit!,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}


