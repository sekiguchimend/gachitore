/// Meal API request/response models

enum MealType {
  breakfast,
  lunch,
  dinner,
  snack,
  preWorkout,
  postWorkout;

  String get value {
    switch (this) {
      case MealType.breakfast:
        return 'breakfast';
      case MealType.lunch:
        return 'lunch';
      case MealType.dinner:
        return 'dinner';
      case MealType.snack:
        return 'snack';
      case MealType.preWorkout:
        return 'pre_workout';
      case MealType.postWorkout:
        return 'post_workout';
    }
  }

  String get displayName {
    switch (this) {
      case MealType.breakfast:
        return '朝食';
      case MealType.lunch:
        return '昼食';
      case MealType.dinner:
        return '夕食';
      case MealType.snack:
        return '間食';
      case MealType.preWorkout:
        return 'プレワークアウト';
      case MealType.postWorkout:
        return 'ポストワークアウト';
    }
  }

  static MealType fromString(String value) {
    switch (value) {
      case 'breakfast':
        return MealType.breakfast;
      case 'lunch':
        return MealType.lunch;
      case 'dinner':
        return MealType.dinner;
      case 'snack':
        return MealType.snack;
      case 'pre_workout':
        return MealType.preWorkout;
      case 'post_workout':
        return MealType.postWorkout;
      default:
        return MealType.snack;
    }
  }
}

class LogMealRequest {
  final DateTime date;
  final DateTime? time;
  final MealType mealType;
  final int? mealIndex;
  final String? note;
  final String? photoUrl;
  final List<MealItemRequest> items;

  LogMealRequest({
    required this.date,
    this.time,
    required this.mealType,
    this.mealIndex,
    this.note,
    this.photoUrl,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T')[0],
      if (time != null)
        'time':
            '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}:00',
      'meal_type': mealType.value,
      if (mealIndex != null) 'meal_index': mealIndex,
      if (note != null) 'note': note,
      if (photoUrl != null) 'photo_url': photoUrl,
      'items': items.map((i) => i.toJson()).toList(),
    };
  }
}

class MealItemRequest {
  final String name;
  final double? quantity;
  final String? unit;
  final int? calories;
  final double? proteinG;
  final double? fatG;
  final double? carbsG;
  final double? fiberG;

  MealItemRequest({
    required this.name,
    this.quantity,
    this.unit,
    this.calories,
    this.proteinG,
    this.fatG,
    this.carbsG,
    this.fiberG,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (calories != null) 'calories': calories,
      if (proteinG != null) 'protein_g': proteinG,
      if (fatG != null) 'fat_g': fatG,
      if (carbsG != null) 'carbs_g': carbsG,
      if (fiberG != null) 'fiber_g': fiberG,
    };
  }
}

class LogMealResponse {
  final String mealId;
  final String message;

  LogMealResponse({
    required this.mealId,
    required this.message,
  });

  factory LogMealResponse.fromJson(Map<String, dynamic> json) {
    return LogMealResponse(
      mealId: json['meal_id'],
      message: json['message'],
    );
  }
}

/// Meal entry for display
class MealEntry {
  final String id;
  final MealType type;
  final DateTime time;
  final List<MealItem> items;

  MealEntry({
    required this.id,
    required this.type,
    required this.time,
    required this.items,
  });

  int get totalCalories => items.fold(0, (sum, item) => sum + item.calories);
  double get totalProtein => items.fold(0.0, (sum, item) => sum + item.protein);
  double get totalFat => items.fold(0.0, (sum, item) => sum + item.fat);
  double get totalCarbs => items.fold(0.0, (sum, item) => sum + item.carbs);

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    final timeStr = json['time'];
    final dateStr = json['date'];
    DateTime time;
    if (timeStr != null && dateStr != null) {
      time = DateTime.parse('$dateStr $timeStr');
    } else {
      time = DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String());
    }

    return MealEntry(
      id: json['id'],
      type: MealType.fromString(json['meal_type']),
      time: time,
      items: (json['items'] as List?)
              ?.map((i) => MealItem.fromJson(i))
              .toList() ??
          [],
    );
  }
}

class MealItem {
  final String name;
  final int calories;
  final double protein;
  final double fat;
  final double carbs;

  MealItem({
    required this.name,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  factory MealItem.fromJson(Map<String, dynamic> json) {
    return MealItem(
      name: json['name'],
      calories: json['calories'] ?? 0,
      protein: (json['protein_g'] ?? 0).toDouble(),
      fat: (json['fat_g'] ?? 0).toDouble(),
      carbs: (json['carbs_g'] ?? 0).toDouble(),
    );
  }
}

/// Nutrition summary
class NutritionSummary {
  final int calories;
  final int caloriesGoal;
  final int protein;
  final int proteinGoal;
  final int fat;
  final int fatGoal;
  final int carbs;
  final int carbsGoal;

  NutritionSummary({
    required this.calories,
    required this.caloriesGoal,
    required this.protein,
    required this.proteinGoal,
    required this.fat,
    required this.fatGoal,
    required this.carbs,
    required this.carbsGoal,
  });

  factory NutritionSummary.fromJson(Map<String, dynamic> json) {
    return NutritionSummary(
      calories: json['calories'] ?? 0,
      caloriesGoal: json['calories_goal'] ?? 2400,
      protein: (json['protein_g'] ?? 0).round(),
      proteinGoal: json['protein_goal'] ?? 150,
      fat: (json['fat_g'] ?? 0).round(),
      fatGoal: json['fat_goal'] ?? 80,
      carbs: (json['carbs_g'] ?? 0).round(),
      carbsGoal: json['carbs_goal'] ?? 250,
    );
  }
}
