import 'package:flutter/material.dart';

/// App color definitions
/// Dark theme with green accents
class AppColors {
  AppColors._();

  // === Background Colors ===
  /// Main background (dark navy, almost black)
  static const Color bgMain = Color(0xFF0B141A);

  /// Sub background (tabs, bars)
  static const Color bgSub = Color(0xFF0F1B22);

  /// Card/button background
  static const Color bgCard = Color(0xFF121F27);

  /// Elevated card background
  static const Color bgCardElevated = Color(0xFF1A2830);

  // === Green Accent Colors ===
  /// Primary green (main accent)
  static const Color greenPrimary = Color(0xFF4FB286);

  /// Secondary green (sub text)
  static const Color greenSecondary = Color(0xFF3FA377);

  /// Muted green (disabled, weak accent)
  static const Color greenMuted = Color(0xFF2E6F55);

  // === Text Colors ===
  /// Primary text (white)
  static const Color textPrimary = Color(0xFFFFFFFF);

  /// Secondary text (gray)
  static const Color textSecondary = Color(0xFFB0B8BF);

  /// Tertiary text (dark gray)
  static const Color textTertiary = Color(0xFF6B7680);

  /// Disabled text
  static const Color textDisabled = Color(0xFF4A5560);

  // === Semantic Colors ===
  /// Error/danger red
  static const Color error = Color(0xFFE57373);

  /// Warning orange
  static const Color warning = Color(0xFFFFB74D);

  /// Success green
  static const Color success = Color(0xFF4FB286);

  /// Info blue
  static const Color info = Color(0xFF64B5F6);

  // === Border Colors ===
  /// Default border
  static const Color border = Color(0xFF2A3540);

  /// Focus border
  static const Color borderFocus = Color(0xFF4FB286);

  // === Gradient ===
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [greenPrimary, greenSecondary],
  );
}
