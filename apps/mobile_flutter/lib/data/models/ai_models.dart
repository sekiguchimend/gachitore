/// AI API request/response models

class AskRequest {
  final String message;
  final String? sessionId;

  AskRequest({
    required this.message,
    this.sessionId,
  });

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      if (sessionId != null) 'session_id': sessionId,
    };
  }
}

class AskResponse {
  final String sessionId;
  final String answerText;
  final List<Recommendation> recommendations;
  final List<String> warnings;

  AskResponse({
    required this.sessionId,
    required this.answerText,
    required this.recommendations,
    required this.warnings,
  });

  factory AskResponse.fromJson(Map<String, dynamic> json) {
    return AskResponse(
      sessionId: json['session_id'],
      answerText: json['answer_text'],
      recommendations: (json['recommendations'] as List?)
              ?.map((r) => Recommendation.fromJson(r))
              .toList() ??
          [],
      warnings: (json['warnings'] as List?)?.cast<String>() ?? [],
    );
  }
}

class Recommendation {
  final String id;
  final String kind;
  final Map<String, dynamic> payload;

  Recommendation({
    required this.id,
    required this.kind,
    required this.payload,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'],
      kind: json['kind'],
      payload: json['payload'] ?? {},
    );
  }
}

class PlanTodayRequest {
  final List<String>? muscleGroups;
  final int? durationMinutes;
  final List<String>? equipmentAvailable;

  PlanTodayRequest({
    this.muscleGroups,
    this.durationMinutes,
    this.equipmentAvailable,
  });

  Map<String, dynamic> toJson() {
    return {
      if (muscleGroups != null) 'muscle_groups': muscleGroups,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (equipmentAvailable != null) 'equipment_available': equipmentAvailable,
    };
  }
}

class PlanTodayResponse {
  final String sessionId;
  final WorkoutPlan plan;
  final String answerText;
  final List<String> warnings;

  PlanTodayResponse({
    required this.sessionId,
    required this.plan,
    required this.answerText,
    required this.warnings,
  });

  factory PlanTodayResponse.fromJson(Map<String, dynamic> json) {
    return PlanTodayResponse(
      sessionId: json['session_id'],
      plan: WorkoutPlan.fromJson(json['plan']),
      answerText: json['answer_text'],
      warnings: (json['warnings'] as List?)?.cast<String>() ?? [],
    );
  }
}

class WorkoutPlan {
  final String title;
  final int estimatedDurationMinutes;
  final List<PlannedExercise> exercises;
  final String? notes;

  WorkoutPlan({
    required this.title,
    required this.estimatedDurationMinutes,
    required this.exercises,
    this.notes,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      title: json['title'],
      estimatedDurationMinutes: json['estimated_duration_minutes'] ?? 60,
      exercises: (json['exercises'] as List?)
              ?.map((e) => PlannedExercise.fromJson(e))
              .toList() ??
          [],
      notes: json['notes'],
    );
  }
}

class PlannedExercise {
  final String name;
  final String muscleTag;
  final int sets;
  final String reps;
  final int restSec;
  final String? notes;

  PlannedExercise({
    required this.name,
    required this.muscleTag,
    required this.sets,
    required this.reps,
    required this.restSec,
    this.notes,
  });

  factory PlannedExercise.fromJson(Map<String, dynamic> json) {
    return PlannedExercise(
      name: json['name'],
      muscleTag: json['muscle_tag'],
      sets: json['sets'],
      reps: json['reps'],
      restSec: json['rest_sec'] ?? 90,
      notes: json['notes'],
    );
  }
}

class AiHistoryResponse {
  final List<AiSessionSummary> sessions;

  AiHistoryResponse({required this.sessions});

  factory AiHistoryResponse.fromJson(Map<String, dynamic> json) {
    return AiHistoryResponse(
      sessions: (json['sessions'] as List?)
              ?.map((s) => AiSessionSummary.fromJson(s))
              .toList() ??
          [],
    );
  }
}

class AiSessionSummary {
  final String id;
  final String intent;
  final DateTime createdAt;

  AiSessionSummary({
    required this.id,
    required this.intent,
    required this.createdAt,
  });

  factory AiSessionSummary.fromJson(Map<String, dynamic> json) {
    return AiSessionSummary(
      id: json['id'],
      intent: json['intent'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

/// Chat message for display
class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final List<Recommendation>? recommendations;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.recommendations,
  });
}

/// Inbox message for bot notifications (e.g., meal reminders)
class AiInboxMessage {
  final String id;
  final String content;
  final String kind;
  final String mealType;
  final DateTime createdAt;

  AiInboxMessage({
    required this.id,
    required this.content,
    required this.kind,
    required this.mealType,
    required this.createdAt,
  });

  factory AiInboxMessage.fromJson(Map<String, dynamic> json) {
    return AiInboxMessage(
      id: json['id'],
      content: json['content'] ?? '',
      kind: json['kind'] ?? '',
      mealType: json['meal_type'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
