import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/chat_history_storage.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/settings/settings_tiles.dart';
import '../../widgets/settings/picker_bottom_sheet.dart';
import 'user_profile.dart';

part 'settings_page_ui.dart';
part 'settings_page_dialogs.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  UserProfile? _user;
  bool _isLoading = true;

  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadNotificationSetting();
  }

  Future<void> _loadNotificationSetting() async {
    try {
      final settings = ref.read(appSettingsServiceProvider);
      final enabled = await settings.isPushNotificationsEnabled();
      if (!mounted) return;
      setState(() => _notificationsEnabled = enabled);
    } catch (_) {
      // ignore (defaults to true)
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final authService = ref.read(authServiceProvider);
      final profile = await authService.getUserProfile();
      if (mounted) {
        setState(() {
          _user = profile != null ? UserProfile.fromJson(profile) : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onNotificationsChanged(bool value) async {
    setState(() => _notificationsEnabled = value);

    final settings = ref.read(appSettingsServiceProvider);
    final push = ref.read(pushNotificationServiceProvider);

    await settings.setPushNotificationsEnabled(value);

    if (!value) {
      // 画面操作を止めない（best-effortでサーバー登録解除）
      unawaited(push.disablePush());
      return;
    }

    final ok = await push.enablePushAndSync(platform: 'app');
    if (ok) return;

    // 権限がない/拒否された場合はOFFへ戻す
    if (!mounted) return;
    setState(() => _notificationsEnabled = false);
    await settings.setPushNotificationsEnabled(false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('通知が許可されていないためONにできませんでした'),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _updateProfile({
    String? displayName,
    String? goal,
    String? trainingLevel,
    double? weightKg,
    int? heightCm,
    int? birthYear,
    int? targetCalories,
    int? targetProteinG,
    int? targetFatG,
    int? targetCarbsG,
  }) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.updateProfile(
        displayName: displayName,
        goal: goal,
        trainingLevel: trainingLevel,
        weightKg: weightKg,
        heightCm: heightCm,
        birthYear: birthYear,
        targetCalories: targetCalories,
        targetProteinG: targetProteinG,
        targetFatG: targetFatG,
        targetCarbsG: targetCarbsG,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('保存しました'),
            backgroundColor: AppColors.greenPrimary,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('保存に失敗しました: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.greenPrimary,
          ),
        ),
      );
    }

    final user = _user ?? UserProfile.empty();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(),

              // Profile Card
              _buildProfileCard(user),

              // Stats Summary
              _buildStatsSummary(),

              // Settings Sections
              SettingsSection(
                title: '目標設定',
                children: [
                  SettingsTile(
                    icon: Icons.flag_outlined,
                    title: '目標',
                    subtitle: user.goal,
                    onTap: () => _showGoalPicker(),
                  ),
                  SettingsTile(
                    icon: Icons.trending_up,
                    title: 'トレーニングレベル',
                    subtitle: user.level,
                    onTap: () => _showLevelPicker(),
                  ),
                  SettingsTile(
                    icon: Icons.restaurant_menu,
                    title: '1日のPFC目標',
                    subtitle:
                        '${user.targetCalories}kcal / P${user.targetProteinG}g F${user.targetFatG}g C${user.targetCarbsG}g',
                    onTap: () => _showPfcEditor(),
                  ),
                ],
              ),

              SettingsSection(
                title: '身体データ',
                children: [
                  SettingsTile(
                    icon: Icons.monitor_weight_outlined,
                    title: '体重',
                    subtitle: '${user.weight}kg',
                    onTap: () => _showWeightEditor(),
                  ),
                  SettingsTile(
                    icon: Icons.height,
                    title: '身長',
                    subtitle: '${user.height}cm',
                    onTap: () => _showHeightEditor(),
                  ),
                  SettingsTile(
                    icon: Icons.cake_outlined,
                    title: '年齢',
                    subtitle: '${user.age}歳',
                    onTap: () => _showAgeEditor(),
                  ),
                ],
              ),

              SettingsSection(
                title: 'アプリ設定',
                children: [
                  SettingsSwitchTile(
                    icon: Icons.notifications_outlined,
                    title: '通知',
                    subtitle: 'トレーニングリマインダーなど',
                    value: _notificationsEnabled,
                    onChanged: _onNotificationsChanged,
                  ),
                ],
              ),

              SettingsSection(
                title: 'サポート',
                children: [
                  SettingsTile(
                    icon: Icons.help_outline,
                    title: 'ヘルプ',
                    subtitle: 'よくある質問',
                    onTap: () => context.push('/support/help'),
                  ),
                  SettingsTile(
                    icon: Icons.mail_outline,
                    title: 'お問い合わせ',
                    subtitle: 'フィードバックを送る',
                    onTap: () => context.push('/support/contact'),
                  ),
                  SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'プライバシーポリシー',
                    subtitle: null,
                    onTap: () => context.push('/support/privacy'),
                  ),
                  SettingsTile(
                    icon: Icons.description_outlined,
                    title: '利用規約',
                    subtitle: null,
                    onTap: () => context.push('/support/terms'),
                  ),
                ],
              ),

              // Logout Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppOutlinedButton(
                  text: 'ログアウト',
                  icon: Icons.logout,
                  isExpanded: true,
                  onPressed: () => _showLogoutConfirmation(),
                ),
              ),

              // Version
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Text(
                    'バージョン 1.0.0',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
