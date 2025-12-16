/// Dashboard API response models

class DashboardResponse {
  final DateTime date;
  final BodyMetricsData? bodyMetrics;
  final NutritionData? nutrition;
  final int workoutCount;
  final TasksData tasks;

  DashboardResponse({
    required this.date,
    this.bodyMetrics,
    this.nutrition,
    required this.workoutCount,
    required this.tasks,
  });

  factory DashboardResponse.fromJson(Map<String, dynamic> json) {
    return DashboardResponse(
      date: DateTime.parse(json['date']),
      bodyMetrics: json['body_metrics'] != null
          ? BodyMetricsData.fromJson(json['body_metrics'])
          : null,
      nutrition: json['nutrition'] != null
          ? NutritionData.fromJson(json['nutrition'])
          : null,
      workoutCount: json['workout_count'] ?? 0,
      tasks: TasksData.fromJson(json['tasks']),
    );
  }
}

class BodyMetricsData {
  final double? weightKg;
  final double? bodyfatPct;
  final double? sleepHours;
  final int? steps;

  BodyMetricsData({
    this.weightKg,
    this.bodyfatPct,
    this.sleepHours,
    this.steps,
  });

  factory BodyMetricsData.fromJson(Map<String, dynamic> json) {
    return BodyMetricsData(
      weightKg: json['weight_kg']?.toDouble(),
      bodyfatPct: json['bodyfat_pct']?.toDouble(),
      sleepHours: json['sleep_hours']?.toDouble(),
      steps: json['steps'],
    );
  }
}

class NutritionData {
  final int calories;
  final double proteinG;
  final double fatG;
  final double carbsG;
  final int mealsLogged;

  NutritionData({
    required this.calories,
    required this.proteinG,
    required this.fatG,
    required this.carbsG,
    required this.mealsLogged,
  });

  factory NutritionData.fromJson(Map<String, dynamic> json) {
    return NutritionData(
      calories: json['calories'] ?? 0,
      proteinG: (json['protein_g'] ?? 0).toDouble(),
      fatG: (json['fat_g'] ?? 0).toDouble(),
      carbsG: (json['carbs_g'] ?? 0).toDouble(),
      mealsLogged: json['meals_logged'] ?? 0,
    );
  }
}

class TasksData {
  final bool weightLogged;
  final bool mealsCompleted;
  final int mealsTarget;
  final int mealsLogged;
  final bool workoutLogged;

  TasksData({
    required this.weightLogged,
    required this.mealsCompleted,
    required this.mealsTarget,
    required this.mealsLogged,
    required this.workoutLogged,
  });

  factory TasksData.fromJson(Map<String, dynamic> json) {
    return TasksData(
      weightLogged: json['weight_logged'] ?? false,
      mealsCompleted: json['meals_completed'] ?? false,
      mealsTarget: json['meals_target'] ?? 3,
      mealsLogged: json['meals_logged'] ?? 0,
      workoutLogged: json['workout_logged'] ?? false,
    );
  }
}
