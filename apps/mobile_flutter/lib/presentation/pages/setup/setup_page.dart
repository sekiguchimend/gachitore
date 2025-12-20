import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../widgets/common/app_button.dart';
import '../../../core/onboarding/onboarding_progress_storage.dart';
import 'setup_models.dart';
import 'steps/setup_progress_indicator.dart';
import 'steps/setup_goal_step.dart';
import 'steps/setup_level_step.dart';
import 'steps/setup_body_step.dart';
import 'steps/setup_environment_step.dart';
import 'steps/setup_constraints_step.dart';

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

  final List<SetupGoal> _goals = const [
    SetupGoal(id: 'hypertrophy', label: '筋肥大', icon: Icons.trending_up),
    SetupGoal(id: 'cut', label: '減量', icon: Icons.trending_down),
    SetupGoal(id: 'strength', label: 'パワー向上', icon: Icons.fitness_center),
    SetupGoal(id: 'health', label: '健康維持', icon: Icons.favorite),
  ];

  final List<SetupLevel> _levels = const [
    SetupLevel(id: 'beginner', label: '初心者', desc: 'トレーニング歴1年未満'),
    SetupLevel(id: 'intermediate', label: '中級者', desc: 'トレーニング歴1〜3年'),
    SetupLevel(id: 'advanced', label: '上級者', desc: 'トレーニング歴3年以上'),
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
  void initState() {
    super.initState();
    unawaited(_restoreProgress());
  }

  Future<void> _restoreProgress() async {
    final saved = await OnboardingProgressStorage.getSavedStep();
    if (!mounted) return;
    if (saved == null) return;
    if (saved == _currentStep) return;

    setState(() => _currentStep = saved);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _pageController.jumpToPage(saved);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_currentStep < 4) {
      final next = _currentStep + 1;
      unawaited(OnboardingProgressStorage.saveStep(next));
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = next);
    } else {
      _completeSetup();
    }
  }

  Future<void> _previousStep() async {
    if (_currentStep > 0) {
      final prev = _currentStep - 1;
      unawaited(OnboardingProgressStorage.saveStep(prev));
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep = prev);
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

      // 日本語の器具名を英語に変換
      final equipmentMapping = {
        'ダンベル': 'dumbbell',
        'バーベル': 'barbell',
        'ベンチ': 'bench',
        'ケーブル': 'cable',
        'マシン': 'machine',
        'チンニングバー': 'pullup_bar',
        'ケトルベル': 'kettlebell',
        'バンド': 'band',
      };
      final equipment = _selectedEquipment
          .map((e) => equipmentMapping[e] ?? e.toLowerCase())
          .toList();

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
        equipment: equipment,
        constraints: constraints,
        mealsPerDay: _mealsPerDay,
      );

      if (mounted) {
        await OnboardingProgressStorage.setCompletedLocal(true);
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
          SetupProgressIndicator(currentStep: _currentStep),

          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                SetupGoalStep(
                  goals: _goals,
                  selectedGoalId: _selectedGoal,
                  onSelect: (id) => setState(() => _selectedGoal = id),
                ),
                SetupLevelStep(
                  levels: _levels,
                  selectedLevelId: _selectedLevel,
                  onSelect: (id) => setState(() => _selectedLevel = id),
                ),
                SetupBodyStep(
                  selectedSex: _selectedSex,
                  onSexChanged: (v) => setState(() => _selectedSex = v),
                  ageController: _ageController,
                  heightController: _heightController,
                  weightController: _weightController,
                  mealsPerDay: _mealsPerDay,
                  onMealsPerDayChanged: (c) => setState(() => _mealsPerDay = c),
                ),
                SetupEnvironmentStep(
                  hasGym: _hasGym,
                  hasHome: _hasHome,
                  onToggleGym: () => setState(() => _hasGym = !_hasGym),
                  onToggleHome: () => setState(() => _hasHome = !_hasHome),
                  equipment: _equipment,
                  selectedEquipment: _selectedEquipment,
                  onToggleEquipment: (item) {
                    setState(() {
                      if (_selectedEquipment.contains(item)) {
                        _selectedEquipment.remove(item);
                      } else {
                        _selectedEquipment.add(item);
                      }
                    });
                  },
                ),
                SetupConstraintsStep(
                  constraints: _constraints,
                  selectedConstraints: _selectedConstraints,
                  onToggleConstraint: (item) {
                    setState(() {
                      if (_selectedConstraints.contains(item)) {
                        _selectedConstraints.remove(item);
                      } else {
                        _selectedConstraints.add(item);
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          // Bottom button
          _buildBottomButton(),
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
