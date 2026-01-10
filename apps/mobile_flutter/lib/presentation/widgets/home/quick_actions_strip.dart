import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class QuickActionsStrip extends StatelessWidget {
  final void Function(String message) onSendMessage;

  const QuickActionsStrip({
    super.key,
    required this.onSendMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _QuickActionButton(
              label: '今日のメニュー',
              icon: Icons.list_alt,
              onTap: () => onSendMessage('今日のトレーニングメニューを教えて'),
            ),
            const SizedBox(width: 8),
            _QuickActionButton(
              label: '食事提案',
              icon: Icons.restaurant,
              onTap: () => onSendMessage('今日の残りのPFCバランスを考えた食事を提案して'),
            ),
            const SizedBox(width: 8),
            _QuickActionButton(
              label: '停滞診断',
              icon: Icons.trending_up,
              onTap: () => onSendMessage('最近の進捗を分析して、停滞していないか診断して'),
            ),
            const SizedBox(width: 8),
            _QuickActionButton(
              label: 'モチベーション',
              icon: Icons.emoji_events,
              onTap: () => onSendMessage('やる気が出る言葉をかけて'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.greenPrimary.withValues(alpha:0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.greenPrimary.withValues(alpha:0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: AppColors.greenPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.greenPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


