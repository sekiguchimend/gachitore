class UserProfile {
  final String name;
  final String email;
  final String goal;
  final String level;
  final double weight;
  final double height;
  final int age;
  final int targetCalories;
  final int targetProteinG;
  final int targetFatG;
  final int targetCarbsG;
  final String? avatarUrl;

  UserProfile({
    required this.name,
    required this.email,
    required this.goal,
    required this.level,
    required this.weight,
    required this.height,
    required this.age,
    required this.targetCalories,
    required this.targetProteinG,
    required this.targetFatG,
    required this.targetCarbsG,
    this.avatarUrl,
  });

  UserProfile copyWith({
    String? name,
    String? email,
    String? goal,
    String? level,
    double? weight,
    double? height,
    int? age,
    int? targetCalories,
    int? targetProteinG,
    int? targetFatG,
    int? targetCarbsG,
    String? avatarUrl,
  }) {
    return UserProfile(
      name: name ?? this.name,
      email: email ?? this.email,
      goal: goal ?? this.goal,
      level: level ?? this.level,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      age: age ?? this.age,
      targetCalories: targetCalories ?? this.targetCalories,
      targetProteinG: targetProteinG ?? this.targetProteinG,
      targetFatG: targetFatG ?? this.targetFatG,
      targetCarbsG: targetCarbsG ?? this.targetCarbsG,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  // DB英語値 → 日本語表示マッピング
  static const Map<String, String> goalEnToJa = {
    'hypertrophy': '筋肥大',
    'cut': '減量',
    'health': '健康維持',
    'strength': 'パワー向上',
  };

  static const Map<String, String> levelEnToJa = {
    'beginner': '初心者',
    'intermediate': '中級者',
    'advanced': '上級者',
  };

  // 日本語 → DB英語値マッピング
  static const Map<String, String> goalJaToEn = {
    '筋肥大': 'hypertrophy',
    '減量': 'cut',
    '健康維持': 'health',
    'パワー向上': 'strength',
  };

  static const Map<String, String> levelJaToEn = {
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
      targetCalories: 2400,
      targetProteinG: 150,
      targetFatG: 80,
      targetCarbsG: 250,
      avatarUrl: null,
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
      goal: goalEnToJa[goalEn] ?? goalEn,
      level: levelEnToJa[levelEn] ?? levelEn,
      weight: (json['weight_kg'] ?? 70.0).toDouble(),
      height: (json['height_cm'] ?? 170.0).toDouble(),
      age: age,
      targetCalories: (json['target_calories'] is num)
          ? (json['target_calories'] as num).round()
          : 2400,
      targetProteinG: (json['target_protein_g'] is num)
          ? (json['target_protein_g'] as num).round()
          : 150,
      targetFatG: (json['target_fat_g'] is num)
          ? (json['target_fat_g'] as num).round()
          : 80,
      targetCarbsG: (json['target_carbs_g'] is num)
          ? (json['target_carbs_g'] as num).round()
          : 250,
      avatarUrl: json['avatar_url']?.toString(),
    );
  }
}


