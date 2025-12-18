import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/settings/picker_bottom_sheet.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  UserProfile? _user;
  bool _isLoading = true;

  bool _notificationsEnabled = true;
  bool _darkModeEnabled = true;
  String _weightUnit = 'kg';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
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

  Future<void> _updateProfile({
    String? goal,
    String? trainingLevel,
    double? weightKg,
    int? heightCm,
    int? birthYear,
  }) async {
    try {
      final authService = ref.read(authServiceProvider);
      await authService.updateProfile(
        goal: goal,
        trainingLevel: trainingLevel,
        weightKg: weightKg,
        heightCm: heightCm,
        birthYear: birthYear,
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
              _buildSettingsSection(
                '目標設定',
                [
                  _buildSettingsTile(
                    Icons.flag_outlined,
                    '目標',
                    user.goal,
                    () => _showGoalPicker(),
                  ),
                  _buildSettingsTile(
                    Icons.trending_up,
                    'トレーニングレベル',
                    user.level,
                    () => _showLevelPicker(),
                  ),
                  _buildSettingsTile(
                    Icons.restaurant_menu,
                    'PFC目標',
                    '2400kcal / P150g F80g C250g',
                    () => _showPfcEditor(),
                  ),
                ],
              ),

              _buildSettingsSection(
                '身体データ',
                [
                  _buildSettingsTile(
                    Icons.monitor_weight_outlined,
                    '体重',
                    '${user.weight}kg',
                    () => _showWeightEditor(),
                  ),
                  _buildSettingsTile(
                    Icons.height,
                    '身長',
                    '${user.height}cm',
                    () => _showHeightEditor(),
                  ),
                  _buildSettingsTile(
                    Icons.cake_outlined,
                    '年齢',
                    '${user.age}歳',
                    () => _showAgeEditor(),
                  ),
                ],
              ),

              _buildSettingsSection(
                'アプリ設定',
                [
                  _buildSwitchTile(
                    Icons.notifications_outlined,
                    '通知',
                    'トレーニングリマインダーなど',
                    _notificationsEnabled,
                    (value) => setState(() => _notificationsEnabled = value),
                  ),
                  _buildSwitchTile(
                    Icons.dark_mode_outlined,
                    'ダークモード',
                    '画面を暗くする',
                    _darkModeEnabled,
                    (value) => setState(() => _darkModeEnabled = value),
                  ),
                  _buildSettingsTile(
                    Icons.straighten,
                    '単位',
                    _weightUnit == 'kg' ? 'メートル法 (kg/cm)' : 'ヤード・ポンド法 (lb/in)',
                    () => _showUnitPicker(),
                  ),
                ],
              ),

              _buildSettingsSection(
                'サポート',
                [
                  _buildSettingsTile(
                    Icons.help_outline,
                    'ヘルプ',
                    'よくある質問',
                    () {},
                  ),
                  _buildSettingsTile(
                    Icons.mail_outline,
                    'お問い合わせ',
                    'フィードバックを送る',
                    () {},
                  ),
                  _buildSettingsTile(
                    Icons.privacy_tip_outlined,
                    'プライバシーポリシー',
                    null,
                    () {},
                  ),
                  _buildSettingsTile(
                    Icons.description_outlined,
                    '利用規約',
                    null,
                    () {},
                  ),
                ],
              ),

              // Logout Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppOutlinedButton(
                  text: 'ログアウト',
                  icon: Icons.logout,
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

  Widget _buildHeader() {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(
        child: Text(
          '設定',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(UserProfile user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.greenPrimary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person,
              color: AppColors.greenPrimary,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Edit Button
          IconButton(
            onPressed: () => _showProfileEditor(),
            icon: const Icon(
              Icons.edit_outlined,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('ワークアウト', '47', '回')),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('連続日数', '12', '日')),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('総ボリューム', '234', 't')),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.greenPrimary,
                ),
              ),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
    IconData icon,
    String title,
    String? subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.textSecondary,
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            icon,
            color: AppColors.textSecondary,
            size: 22,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.greenPrimary,
          ),
        ],
      ),
    );
  }

  void _showGoalPicker() {
    _showPickerSheet(
      '目標を選択',
      ['筋肥大', '減量', 'パワー向上', '健康維持'],
      _user?.goal ?? '',
      (value) async {
        // 日本語→英語変換してAPIに送信
        final goalEnValue = UserProfile._goalJaToEn[value] ?? 'hypertrophy';
        await _updateProfile(goal: goalEnValue);
        if (mounted && _user != null) {
          setState(() {
            _user = UserProfile(
              name: _user!.name,
              email: _user!.email,
              goal: value,
              level: _user!.level,
              weight: _user!.weight,
              height: _user!.height,
              age: _user!.age,
            );
          });
        }
      },
    );
  }

  void _showLevelPicker() {
    _showPickerSheet(
      'トレーニングレベル',
      ['初心者', '中級者', '上級者'],
      _user?.level ?? '',
      (value) async {
        // 日本語→英語変換してAPIに送信
        final levelEnValue = UserProfile._levelJaToEn[value] ?? 'beginner';
        await _updateProfile(trainingLevel: levelEnValue);
        if (mounted && _user != null) {
          setState(() {
            _user = UserProfile(
              name: _user!.name,
              email: _user!.email,
              goal: _user!.goal,
              level: value,
              weight: _user!.weight,
              height: _user!.height,
              age: _user!.age,
            );
          });
        }
      },
    );
  }

  void _showUnitPicker() {
    _showPickerSheet(
      '単位を選択',
      ['メートル法 (kg/cm)', 'ヤード・ポンド法 (lb/in)'],
      _weightUnit == 'kg' ? 'メートル法 (kg/cm)' : 'ヤード・ポンド法 (lb/in)',
      (value) {
        setState(() {
          _weightUnit = value.contains('kg') ? 'kg' : 'lb';
        });
      },
    );
  }

  void _showPickerSheet(
    String title,
    List<String> options,
    String currentValue,
    ValueChanged<String> onSelected,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => PickerBottomSheet(
        title: title,
        options: options,
        currentValue: currentValue,
        onSelected: (value) {
          onSelected(value);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showProfileEditor() {
    // TODO: Navigate to profile editor
  }

  void _showPfcEditor() {
    // TODO: Navigate to PFC editor
  }

  void _showWeightEditor() {
    final controller = TextEditingController(
      text: _user?.weight.toString() ?? '',
    );
    _showInputDialog(
      title: '体重を入力',
      suffix: 'kg',
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onSave: (value) async {
        final weight = double.tryParse(value);
        if (weight != null && _user != null) {
          await _updateProfile(weightKg: weight);
          if (mounted) {
            setState(() {
              _user = UserProfile(
                name: _user!.name,
                email: _user!.email,
                goal: _user!.goal,
                level: _user!.level,
                weight: weight,
                height: _user!.height,
                age: _user!.age,
              );
            });
          }
        }
      },
    );
  }

  void _showHeightEditor() {
    final controller = TextEditingController(
      text: _user?.height.toInt().toString() ?? '',
    );
    _showInputDialog(
      title: '身長を入力',
      suffix: 'cm',
      controller: controller,
      keyboardType: TextInputType.number,
      onSave: (value) async {
        final height = double.tryParse(value);
        if (height != null && _user != null) {
          await _updateProfile(heightCm: height.toInt());
          if (mounted) {
            setState(() {
              _user = UserProfile(
                name: _user!.name,
                email: _user!.email,
                goal: _user!.goal,
                level: _user!.level,
                weight: _user!.weight,
                height: height,
                age: _user!.age,
              );
            });
          }
        }
      },
    );
  }

  void _showAgeEditor() {
    final controller = TextEditingController(
      text: _user?.age.toString() ?? '',
    );
    _showInputDialog(
      title: '年齢を入力',
      suffix: '歳',
      controller: controller,
      keyboardType: TextInputType.number,
      onSave: (value) async {
        final age = int.tryParse(value);
        if (age != null && _user != null) {
          // 年齢から生年を計算
          final birthYear = DateTime.now().year - age;
          await _updateProfile(birthYear: birthYear);
          if (mounted) {
            setState(() {
              _user = UserProfile(
                name: _user!.name,
                email: _user!.email,
                goal: _user!.goal,
                level: _user!.level,
                weight: _user!.weight,
                height: _user!.height,
                age: age,
              );
            });
          }
        }
      },
    );
  }

  void _showInputDialog({
    required String title,
    required String suffix,
    required TextEditingController controller,
    required TextInputType keyboardType,
    required Future<void> Function(String) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: keyboardType,
              autofocus: true,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                suffixText: suffix,
                suffixStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
                filled: true,
                fillColor: AppColors.bgSub,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await onSave(controller.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.greenPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  '保存',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'ログアウト',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        content: const Text(
          'ログアウトしてもよろしいですか？',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'キャンセル',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final authService = ref.read(authServiceProvider);
                await authService.signOut();
                if (mounted) {
                  context.go('/login');
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ログアウトに失敗しました'),
                    ),
                  );
                }
              }
            },
            child: const Text(
              'ログアウト',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Data Model
class UserProfile {
  final String name;
  final String email;
  final String goal;
  final String level;
  final double weight;
  final double height;
  final int age;

  UserProfile({
    required this.name,
    required this.email,
    required this.goal,
    required this.level,
    required this.weight,
    required this.height,
    required this.age,
  });

  // DB英語値 → 日本語表示マッピング
  static const Map<String, String> _goalEnToJa = {
    'hypertrophy': '筋肥大',
    'cut': '減量',
    'health': '健康維持',
    'strength': 'パワー向上',
  };

  static const Map<String, String> _levelEnToJa = {
    'beginner': '初心者',
    'intermediate': '中級者',
    'advanced': '上級者',
  };

  // 日本語 → DB英語値マッピング
  static const Map<String, String> _goalJaToEn = {
    '筋肥大': 'hypertrophy',
    '減量': 'cut',
    '健康維持': 'health',
    'パワー向上': 'strength',
  };

  static const Map<String, String> _levelJaToEn = {
    '初心者': 'beginner',
    '中級者': 'intermediate',
    '上級者': 'advanced',
  };

  factory UserProfile.empty() {
    return UserProfile(
      name: 'ユーザー',
      email: '',
      goal: '筋肥大',
      level: '初心者',
      weight: 70.0,
      height: 170.0,
      age: 25,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    // 生年から年齢を計算
    int age = 25;
    if (json['birth_year'] != null) {
      age = DateTime.now().year - (json['birth_year'] as int);
    }

    // 英語のgoal/levelを日本語に変換
    final goalEn = json['goal'] ?? 'hypertrophy';
    final levelEn = json['training_level'] ?? 'beginner';

    return UserProfile(
      name: json['display_name'] ?? json['full_name'] ?? 'ユーザー',
      email: json['email'] ?? '',
      goal: _goalEnToJa[goalEn] ?? goalEn,
      level: _levelEnToJa[levelEn] ?? levelEn,
      weight: (json['weight_kg'] ?? 70.0).toDouble(),
      height: (json['height_cm'] ?? 170.0).toDouble(),
      age: age,
    );
  }
}
