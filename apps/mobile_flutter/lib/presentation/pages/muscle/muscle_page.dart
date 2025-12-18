import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/workout_models.dart';
import '../../widgets/common/app_button.dart';

part 'muscle_page.header.dart';
part 'muscle_page.exercises.dart';
part 'muscle_page.history.dart';
part 'muscle_page.sheets_start.dart';
part 'muscle_page.sheets_detail.dart';

class MusclePage extends ConsumerStatefulWidget {
  const MusclePage({super.key});

  @override
  ConsumerState<MusclePage> createState() => _MusclePageState();
}

class _MusclePageState extends ConsumerState<MusclePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedMuscleGroup = 0;
  bool _isLoadingExercises = true;
  bool _isLoadingHistory = true;

  final List<String> _muscleGroups = ['すべて', '胸', '背中', '肩', '腕', '脚', 'コア'];

  // データベースの英語→日本語マッピング
  static const Map<String, String> _muscleEnToJa = {
    'chest': '胸',
    'back': '背中',
    'shoulder': '肩',
    'biceps': '腕',
    'triceps': '腕',
    'quadriceps': '脚',
    'hamstrings': '脚',
    'glutes': '脚',
    'calves': '脚',
    'abs': 'コア',
  };

  // 日本語→英語のリスト（フィルタリング用）
  static const Map<String, List<String>> _muscleJaToEn = {
    '胸': ['chest'],
    '背中': ['back'],
    '肩': ['shoulder'],
    '腕': ['biceps', 'triceps'],
    '脚': ['quadriceps', 'hamstrings', 'glutes', 'calves'],
    'コア': ['abs'],
  };

  List<Exercise> _exercises = [];
  List<WorkoutSession> _recentWorkouts = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadExercises(),
      _loadWorkoutHistory(),
    ]);
  }

  Future<void> _loadExercises() async {
    try {
      final workoutService = ref.read(workoutServiceProvider);
      final exercises = await workoutService.getExercisesWithStats();
      if (mounted) {
        setState(() {
          _exercises = exercises;
          _isLoadingExercises = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingExercises = false);
      }
    }
  }

  Future<void> _loadWorkoutHistory() async {
    try {
      final workoutService = ref.read(workoutServiceProvider);
      final history = await workoutService.getWorkoutHistory();
      if (mounted) {
        setState(() {
          _recentWorkouts = history;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 記録済みの種目のみを取得（lastWeightまたはlastRepsが0より大きい）
  List<Exercise> get _recordedExercises {
    return _exercises.where((e) => e.lastWeight > 0 || e.lastReps > 0).toList();
  }

  List<Exercise> get _filteredExercises {
    final recorded = _recordedExercises;
    if (_selectedMuscleGroup == 0) return recorded;
    final group = _muscleGroups[_selectedMuscleGroup];
    final targetMuscles = _muscleJaToEn[group] ?? [];
    return recorded.where((e) => targetMuscles.contains(e.muscleGroup)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Tab Bar
            _buildTabBar(),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildExercisesTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showStartWorkoutSheet(),
        backgroundColor: AppColors.greenPrimary,
        icon: const Icon(Icons.play_arrow, color: AppColors.textPrimary),
        label: const Text(
          'ワークアウト開始',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
