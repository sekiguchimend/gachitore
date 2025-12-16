import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../widgets/common/app_button.dart';
import '../../widgets/common/app_text_field.dart';

class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<SetupPage> {
  final _pageController = PageController();
  int _currentStep = 0;
  bool _isLoading = false;

  // Form data
  String? _selectedGoal;
  String? _selectedLevel;
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedSex = 'male';
  bool _hasGym = false;
  bool _hasHome = false;
  final Set<String> _selectedEquipment = {};
  final Set<String> _selectedConstraints = {};
  int _mealsPerDay = 3;

  final _goals = [
    {'id': 'cut', 'label': 'ダイエット', 'icon': Icons.trending_down},
    {'id': 'hypertrophy', 'label': '増量', 'icon': Icons.trending_up},
    {'id': 'strength', 'label': '絞り', 'icon': Icons.fitness_center},
    {'id': 'health', 'label': '健康', 'icon': Icons.favorite},
  ];

  final _levels = [
    {'id': 'beginner', 'label': '初心者', 'desc': 'トレーニング歴1年未満'},
    {'id': 'intermediate', 'label': '中級者', 'desc': 'トレーニング歴1〜3年'},
    {'id': 'advanced', 'label': '上級者', 'desc': 'トレーニング歴3年以上'},
  ];

  final _equipment = [
    'ダンベル',
    'バーベル',
    'ベンチ',
    'ケーブル',
    'マシン',
    'チンニングバー',
    'ケトルベル',
    'バンド',
  ];

  final _constraints = [
    '肩',
    '腰',
    '膝',
    '手首',
    '首',
    '肘',
    '足首',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    } else {
      _completeSetup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _completeSetup() async {
    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);

      // Parse values
      final weight = double.tryParse(_weightController.text) ?? 70.0;
      final height = double.tryParse(_heightController.text) ?? 170.0;
      final age = int.tryParse(_ageController.text) ?? 25;

      // Determine environment
      String environment = 'gym';
      if (_hasGym && _hasHome) {
        environment = 'both';
      } else if (_hasHome) {
        environment = 'home';
      }

      // Combine equipment and constraints
      final constraints = _selectedConstraints.toList();

      await authService.completeOnboarding(
        goal: _selectedGoal ?? 'hypertrophy',
        level: _selectedLevel ?? 'intermediate',
        weight: weight,
        height: height,
        age: age,
        sex: _selectedSex,
        environment: environment,
        constraints: constraints,
      );

      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('初期設定'),
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _previousStep,
              )
            : null,
      ),
      body: Column(
        children: [
          // Progress indicator
          _buildProgressIndicator(),

          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildGoalStep(),
                _buildLevelStep(),
                _buildBodyStep(),
                _buildEnvironmentStep(),
                _buildConstraintsStep(),
              ],
            ),
          ),

          // Bottom button
          _buildBottomButton(),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: List.generate(5, (index) {
          final isCompleted = index < _currentStep;
          final isCurrent = index == _currentStep;
          return Expanded(
            child: Container(
              height: 4,
              margin: EdgeInsets.only(right: index < 4 ? 8 : 0),
              decoration: BoxDecoration(
                color: isCompleted || isCurrent
                    ? AppColors.greenPrimary
                    : AppColors.bgCard,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildGoalStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '目標を選択',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'あなたのトレーニング目標を教えてください',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          ...(_goals.map((goal) => _buildGoalCard(
                goal['id'] as String,
                goal['label'] as String,
                goal['icon'] as IconData,
              ))),
        ],
      ),
    );
  }

  Widget _buildGoalCard(String id, String label, IconData icon) {
    final isSelected = _selectedGoal == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedGoal = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.greenPrimary.withOpacity(0.15) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.greenPrimary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.greenPrimary.withOpacity(0.2)
                    : AppColors.bgSub,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.greenPrimary : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? AppColors.greenPrimary : AppColors.textPrimary,
                ),
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

  Widget _buildLevelStep() {
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
          ...(_levels.map((level) => _buildLevelCard(
                level['id'] as String,
                level['label'] as String,
                level['desc'] as String,
              ))),
        ],
      ),
    );
  }

  Widget _buildLevelCard(String id, String label, String desc) {
    final isSelected = _selectedLevel == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedLevel = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.greenPrimary.withOpacity(0.15) : AppColors.bgCard,
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

  Widget _buildBodyStep() {
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
                child: _buildSexButton('male', '男性', Icons.male),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSexButton('female', '女性', Icons.female),
              ),
            ],
          ),
          const SizedBox(height: 20),

          AppNumberField(
            controller: _ageController,
            label: '年齢',
            hint: '25',
            unit: '歳',
            allowDecimal: false,
          ),
          const SizedBox(height: 20),
          AppNumberField(
            controller: _heightController,
            label: '身長',
            hint: '170',
            unit: 'cm',
            allowDecimal: false,
          ),
          const SizedBox(height: 20),
          AppNumberField(
            controller: _weightController,
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
              final isSelected = _mealsPerDay == count;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _mealsPerDay = count),
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
                          color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
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

  Widget _buildSexButton(String value, String label, IconData icon) {
    final isSelected = _selectedSex == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedSex = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.greenPrimary.withOpacity(0.15) : AppColors.bgCard,
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

  Widget _buildEnvironmentStep() {
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
                child: _buildToggleCard('ジム', Icons.fitness_center, _hasGym, () {
                  setState(() => _hasGym = !_hasGym);
                }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildToggleCard('自宅', Icons.home, _hasHome, () {
                  setState(() => _hasHome = !_hasHome);
                }),
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
            children: _equipment.map((item) {
              final isSelected = _selectedEquipment.contains(item);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedEquipment.remove(item);
                    } else {
                      _selectedEquipment.add(item);
                    }
                  });
                },
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

  Widget _buildToggleCard(String label, IconData icon, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.greenPrimary.withOpacity(0.15) : AppColors.bgCard,
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

  Widget _buildConstraintsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '身体の制約',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '痛みや制限がある部位を選択してください（任意）',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _constraints.map((item) {
              final isSelected = _selectedConstraints.contains(item);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedConstraints.remove(item);
                    } else {
                      _selectedConstraints.add(item);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.warning.withOpacity(0.15) : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.warning : AppColors.border,
                    ),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.warning : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '選択した部位を考慮してAIがメニューを提案します',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    final isValid = _canProceed();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.bgSub,
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: SafeArea(
        child: AppButton(
          text: _currentStep == 4 ? '完了' : '次へ',
          onPressed: isValid ? _nextStep : null,
          isLoading: _isLoading,
          isExpanded: true,
        ),
      ),
    );
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return _selectedGoal != null;
      case 1:
        return _selectedLevel != null;
      case 2:
        return true; // Body info is optional
      case 3:
        return _hasGym || _hasHome;
      case 4:
        return true; // Constraints are optional
      default:
        return false;
    }
  }
}
