/// Workout API request/response models

class LogWorkoutRequest {
  final DateTime date;
  final DateTime? startTime;
  final DateTime? endTime;
  final int? perceivedFatigue;
  final String? note;
  final List<WorkoutExerciseRequest> exercises;

  LogWorkoutRequest({
    required this.date,
    this.startTime,
    this.endTime,
    this.perceivedFatigue,
    this.note,
    required this.exercises,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0],
      if (startTime != null) 'start_time': startTime!.toUtc().toIso8601String(),
      if (endTime != null) 'end_time': endTime!.toUtc().toIso8601String(),
      if (perceivedFatigue != null) 'perceived_fatigue': perceivedFatigue,
      if (note != null) 'note': note,
      'exercises': exercises.map((e) => e.toJson()).toList(),
    };
  }
}

class WorkoutExerciseRequest {
  final String? exerciseId;
  final String? customName;
  final String muscleTag;
  final List<WorkoutSetRequest> sets;

  WorkoutExerciseRequest({
    this.exerciseId,
    this.customName,
    required this.muscleTag,
    required this.sets,
  });

  Map<String, dynamic> toJson() {
    return {
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (customName != null) 'custom_name': customName,
      'muscle_tag': muscleTag,
      'sets': sets.map((s) => s.toJson()).toList(),
    };
  }
}

class WorkoutSetRequest {
  final double? weightKg;
  final int? reps;
  final double? rpe;
  final int? restSec;
  final bool? isWarmup;
  final bool? isDropset;

  WorkoutSetRequest({
    this.weightKg,
    this.reps,
    this.rpe,
    this.restSec,
    this.isWarmup,
    this.isDropset,
  });

  Map<String, dynamic> toJson() {
    return {
      if (weightKg != null) 'weight_kg': weightKg,
      if (reps != null) 'reps': reps,
      if (rpe != null) 'rpe': rpe,
      if (restSec != null) 'rest_sec': restSec,
      if (isWarmup != null) 'is_warmup': isWarmup,
      if (isDropset != null) 'is_dropset': isDropset,
    };
  }
}

class LogWorkoutResponse {
  final String workoutId;
  final String message;

  LogWorkoutResponse({
    required this.workoutId,
    required this.message,
  });

  factory LogWorkoutResponse.fromJson(Map<String, dynamic> json) {
    return LogWorkoutResponse(
      workoutId: json['workout_id'],
      message: json['message'],
    );
  }
}

/// Exercise model for display
class Exercise {
  final String id;
  final String name;
  final String muscleGroup;
  final double e1rm;
  final double lastWeight;
  final int lastReps;
  final double trend;

  Exercise({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.e1rm,
    required this.lastWeight,
    required this.lastReps,
    required this.trend,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      name: json['name'],
      muscleGroup: json['muscle_group'] ?? json['primary_muscles']?[0] ?? '',
      e1rm: (json['e1rm'] ?? 0).toDouble(),
      lastWeight: (json['last_weight'] ?? 0).toDouble(),
      lastReps: json['last_reps'] ?? 0,
      trend: (json['trend'] ?? 0).toDouble(),
    );
  }
}

/// Workout session for history display
class WorkoutSession {
  final String id;
  final DateTime date;
  final String name;
  final int exerciseCount;
  final Duration duration;
  final int totalVolume;

  WorkoutSession({
    required this.id,
    required this.date,
    required this.name,
    required this.exerciseCount,
    required this.duration,
    required this.totalVolume,
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final startTime = json['start_time'] != null
        ? DateTime.parse(json['start_time'])
        : null;
    final endTime = json['end_time'] != null
        ? DateTime.parse(json['end_time'])
        : null;
    final duration = startTime != null && endTime != null
        ? endTime.difference(startTime)
        : Duration.zero;

    return WorkoutSession(
      id: json['id'],
      date: DateTime.parse(json['date']),
      name: json['name'] ?? '未命名のワークアウト',
      exerciseCount: json['exercise_count'] ?? 0,
      duration: duration,
      totalVolume: json['total_volume'] ?? 0,
    );
  }
}
