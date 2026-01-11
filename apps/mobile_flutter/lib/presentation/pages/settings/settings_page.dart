import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/chat_history_storage.dart';
import '../../../data/models/subscription_models.dart';
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
  bool _isUploadingAvatar = false;

  bool _notificationsEnabled = true;

  // ワークアウト統計
  int _totalWorkouts = 0;
  int _streakDays = 0;
  double _totalVolume = 0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadNotificationSetting();
    _loadWorkoutStats();
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

  Future<void> _loadWorkoutStats() async {
    try {
      final workoutService = ref.read(workoutServiceProvider);
      final workouts = await workoutService.getWorkoutHistory(limit: 1000);

      if (!mounted) return;

      // 総ワークアウト数
      final totalWorkouts = workouts.length;

      // 総ボリューム（トン単位）
      double totalVolume = 0;
      for (final w in workouts) {
        totalVolume += w.totalVolume;
      }
      // kgからトンに変換
      totalVolume = totalVolume / 1000;

      // 連続日数（ストリーク）を計算
      int streakDays = 0;
      if (workouts.isNotEmpty) {
        // 日付でソート（新しい順）
        final sortedWorkouts = List.of(workouts)
          ..sort((a, b) => b.date.compareTo(a.date));

        final today = DateTime.now();
        final todayDate = DateTime(today.year, today.month, today.day);

        // 最新のワークアウトが今日か昨日かをチェック
        final latestDate = DateTime(
          sortedWorkouts.first.date.year,
          sortedWorkouts.first.date.month,
          sortedWorkouts.first.date.day,
        );

        final daysDiff = todayDate.difference(latestDate).inDays;
        if (daysDiff <= 1) {
          // ストリークをカウント
          streakDays = 1;
          DateTime? prevDate = latestDate;

          for (int i = 1; i < sortedWorkouts.length; i++) {
            final currentDate = DateTime(
              sortedWorkouts[i].date.year,
              sortedWorkouts[i].date.month,
              sortedWorkouts[i].date.day,
            );

            final diff = prevDate!.difference(currentDate).inDays;
            if (diff == 0) {
              // 同じ日、スキップ
              continue;
            } else if (diff == 1) {
              // 連続日
              streakDays++;
              prevDate = currentDate;
            } else {
              // 連続が途切れた
              break;
            }
          }
        }
      }

      setState(() {
        _totalWorkouts = totalWorkouts;
        _streakDays = streakDays;
        _totalVolume = totalVolume;
      });
    } catch (e) {
      // エラー時はデフォルト値のまま
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

  void _showAvatarPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.greenPrimary),
                title: const Text('ギャラリーから選択', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.greenPrimary),
                title: const Text('カメラで撮影', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    if (_isUploadingAvatar) return;

    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 512, maxHeight: 512);
    if (file == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final authService = ref.read(authServiceProvider);
      final newAvatarUrl = await authService.uploadAvatar(file);
      
      if (!mounted) return;
      setState(() {
        _user = _user?.copyWith(avatarUrl: newAvatarUrl);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('アイコンを更新しました'),
          backgroundColor: AppColors.greenPrimary,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('アップロードに失敗しました: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Widget _buildPlanTile() {
    final subscriptionTierAsync = ref.watch(subscriptionTierProvider);
    
    // サブスクリプション機能はAndroid/iOSのみ対応（Web非対応）
    final isMobilePlatform = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
         defaultTargetPlatform == TargetPlatform.iOS);

    return subscriptionTierAsync.when(
      data: (tier) {
        final tierName = switch (tier) {
          SubscriptionTier.free => '無料プラン',
          SubscriptionTier.basic => 'ベーシックプラン',
          SubscriptionTier.premium => 'プレミアムプラン',
        };

        if (isMobilePlatform) {
          return SettingsTile(
            icon: Icons.workspace_premium,
            title: 'プラン変更',
            subtitle: '現在: $tierName',
            onTap: () => context.push('/subscription'),
            iconColor: const Color(0xFFFFD700),
          );
        } else {
          // Web版：プラン表示のみ（課金はモバイルアプリで）
          return SettingsTile(
            icon: Icons.workspace_premium,
            title: '現在のプラン',
            subtitle: tierName,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('プラン変更はモバイルアプリから行えます'),
                  backgroundColor: AppColors.greenPrimary,
                ),
              );
            },
            iconColor: const Color(0xFFFFD700),
          );
        }
      },
      loading: () => SettingsTile(
        icon: Icons.workspace_premium,
        title: isMobilePlatform ? 'プラン変更' : '現在のプラン',
        subtitle: '読み込み中...',
        onTap: isMobilePlatform ? () => context.push('/subscription') : () {},
        iconColor: const Color(0xFFFFD700),
      ),
      error: (_, __) => SettingsTile(
        icon: Icons.workspace_premium,
        title: isMobilePlatform ? 'プラン変更' : '現在のプラン',
        subtitle: '無料プラン',
        onTap: isMobilePlatform ? () => context.push('/subscription') : () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('プラン変更はモバイルアプリから行えます'),
              backgroundColor: AppColors.greenPrimary,
            ),
          );
        },
        iconColor: const Color(0xFFFFD700),
      ),
    );
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

              // プラン変更
              SettingsSection(
                title: 'サブスクリプション',
                children: [
                  _buildPlanTile(),
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
