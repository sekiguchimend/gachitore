import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/workout_models.dart';
import '../../widgets/common/app_button.dart';

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

  Widget _buildHeader() {
    final tabs = ['種目', '履歴'];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: PopupMenuButton<int>(
                offset: const Offset(0, 48),
                color: AppColors.bgCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                onSelected: (index) {
                  _tabController.animateTo(index);
                  setState(() {});
                },
                itemBuilder: (context) => [
                  PopupMenuItem<int>(
                    value: 0,
                    child: Row(
                      children: [
                        Icon(
                          _tabController.index == 0
                              ? Icons.check
                              : Icons.fitness_center,
                          size: 18,
                          color: _tabController.index == 0
                              ? AppColors.greenPrimary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '種目',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _tabController.index == 0
                                ? AppColors.greenPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem<int>(
                    value: 1,
                    child: Row(
                      children: [
                        Icon(
                          _tabController.index == 1
                              ? Icons.check
                              : Icons.history,
                          size: 18,
                          color: _tabController.index == 1
                              ? AppColors.greenPrimary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '履歴',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _tabController.index == 1
                                ? AppColors.greenPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tabs[_tabController.index],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.expand_less,
                      color: AppColors.textSecondary,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      // TODO: Open stats
                    },
                    icon: const Icon(
                      Icons.bar_chart,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: Add new exercise
                    },
                    icon: const Icon(
                      Icons.add,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return const SizedBox.shrink();
  }

  Widget _buildExercisesTab() {
    return Column(
      children: [
        // Muscle Group Filter
        _buildMuscleGroupFilter(),

        // Exercises List
        Expanded(
          child: _isLoadingExercises
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.greenPrimary,
                  ),
                )
              : _filteredExercises.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.fitness_center,
                              size: 48,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedMuscleGroup == 0
                                  ? 'まだトレーニング記録がありません'
                                  : 'この部位の記録がありません',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '下の「ワークアウト開始」ボタンから\n種目を記録しましょう',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadExercises,
                      color: AppColors.greenPrimary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredExercises.length,
                        itemBuilder: (context, index) {
                          return _buildExerciseCard(_filteredExercises[index]);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildMuscleGroupFilter() {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _muscleGroups.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedMuscleGroup == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedMuscleGroup = index),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.greenPrimary : AppColors.bgCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.greenPrimary
                      : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                _muscleGroups[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildExerciseCard(Exercise exercise) {
    return GestureDetector(
      onTap: () => _showExerciseDetail(exercise),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.greenPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.fitness_center,
                color: AppColors.greenPrimary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '前回: ${exercise.lastWeight}kg × ${exercise.lastReps}回',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            // e1RM
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Text(
                      'e1RM',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${exercise.e1rm.toStringAsFixed(1)}kg',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _buildTrendIndicator(exercise.trend),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendIndicator(double trend) {
    if (trend == 0) {
      return const Text(
        '→ 維持',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textTertiary,
        ),
      );
    }

    final isPositive = trend > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPositive ? Icons.trending_up : Icons.trending_down,
          size: 14,
          color: isPositive ? AppColors.success : AppColors.error,
        ),
        const SizedBox(width: 4),
        Text(
          '${isPositive ? '+' : ''}${trend.toStringAsFixed(1)}kg',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isPositive ? AppColors.success : AppColors.error,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryTab() {
    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.greenPrimary,
        ),
      );
    }

    if (_recentWorkouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 48,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            const Text(
              'ワークアウト履歴がありません',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadWorkoutHistory,
      color: AppColors.greenPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _recentWorkouts.length,
        itemBuilder: (context, index) {
          return _buildWorkoutHistoryCard(_recentWorkouts[index]);
        },
      ),
    );
  }

  Widget _buildWorkoutHistoryCard(WorkoutSession session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.greenPrimary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  session.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.greenPrimary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatDate(session.date),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildHistoryStat(
                Icons.fitness_center,
                '${session.exerciseCount}種目',
              ),
              const SizedBox(width: 24),
              _buildHistoryStat(
                Icons.timer_outlined,
                '${session.duration.inMinutes}分',
              ),
              const SizedBox(width: 24),
              _buildHistoryStat(
                Icons.show_chart,
                '${(session.totalVolume / 1000).toStringAsFixed(1)}t',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryStat(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  void _showStartWorkoutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
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
              const Text(
                'ワークアウトを開始',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'テンプレートを選択するか、空のワークアウトを開始',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildWorkoutTemplate(
                      '空のワークアウト',
                      '種目を自由に追加',
                      Icons.add_circle_outline,
                      isEmpty: true,
                    ),
                    _buildWorkoutTemplate(
                      '胸・三頭',
                      'ベンチプレス、ダンベルフライなど',
                      Icons.favorite_outline,
                    ),
                    _buildWorkoutTemplate(
                      '背中・二頭',
                      'デッドリフト、ラットプルなど',
                      Icons.sync_alt,
                    ),
                    _buildWorkoutTemplate(
                      '脚',
                      'スクワット、レッグプレスなど',
                      Icons.directions_walk,
                    ),
                    _buildWorkoutTemplate(
                      '肩',
                      'OHP、サイドレイズなど',
                      Icons.arrow_upward,
                    ),
                    _buildWorkoutTemplate(
                      'Push',
                      '押す動作の種目',
                      Icons.arrow_forward,
                    ),
                    _buildWorkoutTemplate(
                      'Pull',
                      '引く動作の種目',
                      Icons.arrow_back,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkoutTemplate(String name, String description, IconData icon, {bool isEmpty = false}) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        if (isEmpty) {
          _showExerciseSelectionSheet();
        } else {
          // TODO: Start workout with template
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgSub,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.greenPrimary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.greenPrimary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textTertiary,
                    ),
                  ),
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

  void _showExerciseSelectionSheet() {
    int selectedFilter = 0;
    String searchQuery = '';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          // フィルタリング: 検索 + 部位
          List<Exercise> filtered = _exercises;
          
          if (searchQuery.isNotEmpty) {
            filtered = filtered.where((e) => 
              e.name.toLowerCase().contains(searchQuery.toLowerCase())
            ).toList();
          }
          
          if (selectedFilter > 0) {
            final group = _muscleGroups[selectedFilter];
            final targetMuscles = _muscleJaToEn[group] ?? [];
            filtered = filtered.where((e) => targetMuscles.contains(e.muscleGroup)).toList();
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.9,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Text(
                            '種目を選択',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // 検索バー
                      TextField(
                        onChanged: (value) => setSheetState(() => searchQuery = value),
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '種目を検索...',
                          hintStyle: TextStyle(color: AppColors.textTertiary),
                          prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: AppColors.bgSub,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                // 部位フィルター
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _muscleGroups.length,
                    itemBuilder: (context, index) {
                      final isSelected = selectedFilter == index;
                      return GestureDetector(
                        onTap: () => setSheetState(() => selectedFilter = index),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.greenPrimary : AppColors.bgSub,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _muscleGroups[index],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // 種目リスト
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            '種目が見つかりません',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final exercise = filtered[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _showLogSetSheet(exercise);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.bgSub,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.greenPrimary.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.fitness_center,
                                        color: AppColors.greenPrimary,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            exercise.name,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _muscleEnToJa[exercise.muscleGroup] ?? exercise.muscleGroup,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textTertiary,
                                            ),
                                          ),
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
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showExerciseDetail(Exercise exercise) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
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
              exercise.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _muscleEnToJa[exercise.muscleGroup] ?? exercise.muscleGroup,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildDetailStat('e1RM', '${exercise.e1rm}kg'),
                ),
                Expanded(
                  child: _buildDetailStat(
                      '前回', '${exercise.lastWeight}kg×${exercise.lastReps}'),
                ),
                Expanded(
                  child: _buildDetailStat(
                    'トレンド',
                    exercise.trend >= 0
                        ? '+${exercise.trend}kg'
                        : '${exercise.trend}kg',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppOutlinedButton(
                    text: '履歴を見る',
                    icon: Icons.history,
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Show history
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    text: '記録する',
                    icon: Icons.add,
                    onPressed: () {
                      Navigator.pop(context);
                      _showLogSetSheet(exercise);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showLogSetSheet(Exercise exercise) {
    final weightController = TextEditingController(
      text: exercise.lastWeight > 0 ? exercise.lastWeight.toString() : '',
    );
    final repsController = TextEditingController(
      text: exercise.lastReps > 0 ? exercise.lastReps.toString() : '',
    );
    bool isLogging = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
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
                  exercise.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '重量 (kg)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: weightController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: AppColors.textTertiary,
                              ),
                              filled: true,
                              fillColor: AppColors.bgSub,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '回数',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: repsController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: AppColors.textTertiary,
                              ),
                              filled: true,
                              fillColor: AppColors.bgSub,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: '記録する',
                  isLoading: isLogging,
                  onPressed: () async {
                    final weight = double.tryParse(weightController.text);
                    final reps = int.tryParse(repsController.text);

                    if (weight == null || reps == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('重量と回数を入力してください'),
                        ),
                      );
                      return;
                    }

                    setSheetState(() => isLogging = true);

                    try {
                      final workoutService = ref.read(workoutServiceProvider);
                      await workoutService.logWorkout(
                        LogWorkoutRequest(
                          date: DateTime.now(),
                          startTime: DateTime.now(),
                          endTime: DateTime.now(),
                          exercises: [
                            WorkoutExerciseRequest(
                              exerciseId: exercise.id,
                              muscleTag: exercise.muscleGroup,
                              sets: [
                                WorkoutSetRequest(
                                  weightKg: weight,
                                  reps: reps,
                                ),
                              ],
                            ),
                          ],
                        ),
                      );

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('記録しました'),
                          ),
                        );
                        _loadData();
                      }
                    } catch (e) {
                      setSheetState(() => isLogging = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('記録に失敗しました'),
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '今日';
    } else if (diff.inDays == 1) {
      return '昨日';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}日前';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
