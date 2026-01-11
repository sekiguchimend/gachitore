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
part 'muscle_page.copy_workout.dart';

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
  double? _bodyWeight;

  // キャッシュ用
  List<Exercise>? _cachedRecordedExercises;
  List<Exercise>? _cachedFilteredExercises;
  int _lastFilteredMuscleGroup = -1;

  // パフォーマンス最適化: 履歴計算のキャッシュ
  Map<DateTime, double>? _cachedScoreMap;
  Map<DateTime, List<WorkoutSession>>? _cachedGroupedWorkouts;
  List<WorkoutSession>? _lastWorkoutsForCache;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadExercises(),
      _loadWorkoutHistory(),
      _loadBodyWeight(),
    ]);
  }

  Future<void> _loadBodyWeight() async {
    try {
      final authService = ref.read(authServiceProvider);
      final profile = await authService.getUserProfile();
      if (mounted && profile != null) {
        setState(() {
          _bodyWeight = (profile['weight_kg'] as num?)?.toDouble();
        });
      }
    } catch (e) {
      // Ignore error, weight is optional
    }
  }

  Future<void> _loadExercises() async {
    try {
      final workoutService = ref.read(workoutServiceProvider);
      final exercises = await workoutService.getExercisesWithStats();
      if (mounted) {
        setState(() {
          _exercises = exercises;
          _clearExerciseCache();
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
          // パフォーマンス最適化: 履歴キャッシュをクリア
          _clearHistoryCache();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingHistory = false);
      }
    }
  }

  // 履歴キャッシュをクリア
  void _clearHistoryCache() {
    _cachedScoreMap = null;
    _cachedGroupedWorkouts = null;
    _lastWorkoutsForCache = null;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 記録済みの種目のみを取得（キャッシュ付き）
  List<Exercise> get _recordedExercises {
    _cachedRecordedExercises ??= _exercises.where((e) => e.lastWeight > 0 || e.lastReps > 0).toList();
    return _cachedRecordedExercises!;
  }

  // フィルタリング済み種目（キャッシュ付き）
  List<Exercise> get _filteredExercises {
    if (_cachedFilteredExercises != null && _lastFilteredMuscleGroup == _selectedMuscleGroup) {
      return _cachedFilteredExercises!;
    }

    final recorded = _recordedExercises;
    if (_selectedMuscleGroup == 0) {
      _cachedFilteredExercises = recorded;
    } else {
      final group = _muscleGroups[_selectedMuscleGroup];
      final targetMuscles = _muscleJaToEn[group] ?? [];
      _cachedFilteredExercises = recorded.where((e) => targetMuscles.contains(e.muscleGroup)).toList();
    }
    _lastFilteredMuscleGroup = _selectedMuscleGroup;
    return _cachedFilteredExercises!;
  }

  // exercisesが更新されたらキャッシュをクリア
  void _clearExerciseCache() {
    _cachedRecordedExercises = null;
    _cachedFilteredExercises = null;
    _lastFilteredMuscleGroup = -1;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),

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
        icon: const Icon(Icons.add, color: AppColors.textPrimary),
        label: const Text(
          '今日やった種目',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
