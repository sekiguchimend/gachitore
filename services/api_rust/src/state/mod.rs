use chrono::{Datelike, Duration, NaiveDate};
use serde::{Deserialize, Serialize};

use crate::error::AppResult;
use crate::infrastructure::supabase::{
    BodyMetrics, NutritionDaily, SupabaseClient, UserProfile, Workout,
};

/// User state for AI context (version 1)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct UserState {
    pub version: String,
    pub profile: ProfileState,
    pub today: TodayState,
    pub last_14d: Last14dState,
    pub nutrition_7d_avg: NutritionAvgState,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProfileState {
    pub goal: String,
    pub training_level: String,
    pub height_cm: Option<i32>,
    pub sex: Option<String>,
    pub birth_year: Option<i32>,
    pub environment: serde_json::Value,
    pub constraints: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TodayState {
    pub date: NaiveDate,
    pub weight_kg: Option<f64>,
    pub bodyfat_pct: Option<f64>,
    pub sleep_hours: Option<f64>,
    pub steps: Option<i32>,
    pub calories: Option<i32>,
    pub protein_g: Option<f64>,
    pub meals_logged: Option<i32>,
    pub workout_count: i32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Last14dState {
    pub workout_count: i32,
    pub workout_days: Vec<NaiveDate>,
    pub muscle_groups_trained: Vec<String>,
    pub top_exercises: Vec<ExerciseSummary>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExerciseSummary {
    pub name: String,
    pub muscle_tag: String,
    pub e1rm: Option<f64>,
    pub last_weight_kg: Option<f64>,
    pub last_reps: Option<i32>,
    pub trend: String, // "up", "down", "stable"
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NutritionAvgState {
    pub avg_calories: Option<f64>,
    pub avg_protein_g: Option<f64>,
    pub avg_fat_g: Option<f64>,
    pub avg_carbs_g: Option<f64>,
    pub days_logged: i32,
}

/// State generator using Supabase REST API
pub struct StateGenerator<'a> {
    supabase: &'a SupabaseClient,
    access_token: &'a str,
}

impl<'a> StateGenerator<'a> {
    pub fn new(supabase: &'a SupabaseClient, access_token: &'a str) -> Self {
        Self {
            supabase,
            access_token,
        }
    }

    /// Generate complete user state for AI context
    pub async fn generate(&self, user_id: &str, target_date: NaiveDate) -> AppResult<UserState> {
        let profile = self.generate_profile(user_id).await?;
        let today = self.generate_today(user_id, target_date).await?;
        let last_14d = self.generate_last_14d(user_id, target_date).await?;
        let nutrition_7d_avg = self.generate_nutrition_avg(user_id, target_date).await?;

        Ok(UserState {
            version: "v1".to_string(),
            profile,
            today,
            last_14d,
            nutrition_7d_avg,
        })
    }

    async fn generate_profile(&self, user_id: &str) -> AppResult<ProfileState> {
        let query = format!("user_id=eq.{}&select=*", user_id);
        let profiles: Vec<UserProfile> = self
            .supabase
            .select("user_profiles", &query, self.access_token)
            .await?;

        match profiles.into_iter().next() {
            Some(p) => Ok(ProfileState {
                goal: p.goal,
                training_level: p.training_level,
                height_cm: p.height_cm,
                sex: p.sex,
                birth_year: p.birth_year,
                environment: p.environment.unwrap_or(serde_json::json!({})),
                constraints: p.constraints.unwrap_or(serde_json::json!([])),
            }),
            None => Ok(ProfileState {
                goal: "health".to_string(),
                training_level: "beginner".to_string(),
                height_cm: None,
                sex: None,
                birth_year: None,
                environment: serde_json::json!({}),
                constraints: serde_json::json!([]),
            }),
        }
    }

    async fn generate_today(&self, user_id: &str, date: NaiveDate) -> AppResult<TodayState> {
        let date_str = date.format("%Y-%m-%d").to_string();

        // Get body metrics
        let metrics_query = format!("user_id=eq.{}&date=eq.{}&select=*", user_id, date_str);
        let metrics: Vec<BodyMetrics> = self
            .supabase
            .select("body_metrics", &metrics_query, self.access_token)
            .await?;
        let metrics = metrics.into_iter().next();

        // Get nutrition
        let nutrition_query = format!("user_id=eq.{}&date=eq.{}&select=*", user_id, date_str);
        let nutrition: Vec<NutritionDaily> = self
            .supabase
            .select("nutrition_daily", &nutrition_query, self.access_token)
            .await?;
        let nutrition = nutrition.into_iter().next();

        // Get workouts
        let workouts_query = format!("user_id=eq.{}&date=eq.{}&select=*", user_id, date_str);
        let workouts: Vec<Workout> = self
            .supabase
            .select("workouts", &workouts_query, self.access_token)
            .await?;

        Ok(TodayState {
            date,
            weight_kg: metrics.as_ref().and_then(|m| m.weight_kg),
            bodyfat_pct: metrics.as_ref().and_then(|m| m.bodyfat_pct),
            sleep_hours: metrics.as_ref().and_then(|m| m.sleep_hours),
            steps: metrics.as_ref().and_then(|m| m.steps),
            calories: nutrition.as_ref().map(|n| n.calories),
            protein_g: nutrition.as_ref().map(|n| n.protein_g),
            meals_logged: nutrition.as_ref().map(|n| n.meals_logged),
            workout_count: workouts.len() as i32,
        })
    }

    async fn generate_last_14d(&self, user_id: &str, end_date: NaiveDate) -> AppResult<Last14dState> {
        let start_date = end_date - Duration::days(14);
        let start_str = start_date.format("%Y-%m-%d").to_string();
        let end_str = end_date.format("%Y-%m-%d").to_string();

        // Get workouts with exercises and sets in a single JOIN query (fixes N+1)
        let workouts_query = format!(
            "user_id=eq.{}&date=gte.{}&date=lte.{}&select=id,date,workout_exercises(id,exercise_id,custom_exercise_name,muscle_tag,workout_sets(weight_kg,reps,is_warmup))&order=date.desc",
            user_id, start_str, end_str
        );
        let workouts: Vec<serde_json::Value> = self
            .supabase
            .select("workouts", &workouts_query, self.access_token)
            .await?;

        let workout_days: Vec<NaiveDate> = workouts
            .iter()
            .filter_map(|w| {
                w["date"].as_str()
                    .and_then(|d| NaiveDate::parse_from_str(d, "%Y-%m-%d").ok())
            })
            .collect();

        let mut muscle_groups: std::collections::HashSet<String> = std::collections::HashSet::new();
        let mut exercise_data: std::collections::HashMap<String, Vec<(f64, i32, String)>> =
            std::collections::HashMap::new();

        // Process nested data from JOIN query
        for workout in &workouts {
            if let Some(exercises) = workout["workout_exercises"].as_array() {
                for exercise in exercises {
                    let muscle_tag = exercise["muscle_tag"].as_str().unwrap_or_default().to_string();
                    muscle_groups.insert(muscle_tag.clone());

                    let name = exercise["custom_exercise_name"]
                        .as_str()
                        .map(String::from)
                        .unwrap_or_else(|| {
                            format!(
                                "exercise_{}",
                                exercise["exercise_id"].as_str().unwrap_or("unknown")
                            )
                        });

                    if let Some(sets) = exercise["workout_sets"].as_array() {
                        for set in sets {
                            let is_warmup = set["is_warmup"].as_bool().unwrap_or(false);
                            if !is_warmup {
                                if let (Some(weight), Some(reps)) = (
                                    set["weight_kg"].as_f64(),
                                    set["reps"].as_i64().map(|r| r as i32),
                                ) {
                                    exercise_data
                                        .entry(name.clone())
                                        .or_default()
                                        .push((weight, reps, muscle_tag.clone()));
                                }
                            }
                        }
                    }
                }
            }
        }

        // Calculate top exercises with e1RM
        let mut top_exercises: Vec<ExerciseSummary> = exercise_data
            .into_iter()
            .filter_map(|(name, sets)| {
                if sets.is_empty() {
                    return None;
                }

                let last = sets.last()?;
                let first = sets.first()?;

                let e1rm = calculate_e1rm(last.0, last.1);
                let first_e1rm = calculate_e1rm(first.0, first.1);

                let trend = if e1rm > first_e1rm * 1.02 {
                    "up"
                } else if e1rm < first_e1rm * 0.98 {
                    "down"
                } else {
                    "stable"
                };

                Some(ExerciseSummary {
                    name,
                    muscle_tag: last.2.clone(),
                    e1rm: Some(e1rm),
                    last_weight_kg: Some(last.0),
                    last_reps: Some(last.1),
                    trend: trend.to_string(),
                })
            })
            .collect();

        // Sort by e1RM descending and take top 10
        top_exercises.sort_by(|a, b| {
            b.e1rm
                .unwrap_or(0.0)
                .partial_cmp(&a.e1rm.unwrap_or(0.0))
                .unwrap()
        });
        top_exercises.truncate(10);

        Ok(Last14dState {
            workout_count: workouts.len() as i32,
            workout_days,
            muscle_groups_trained: muscle_groups.into_iter().collect(),
            top_exercises,
        })
    }

    async fn generate_nutrition_avg(
        &self,
        user_id: &str,
        end_date: NaiveDate,
    ) -> AppResult<NutritionAvgState> {
        let start_date = end_date - Duration::days(7);
        let start_str = start_date.format("%Y-%m-%d").to_string();
        let end_str = end_date.format("%Y-%m-%d").to_string();

        let query = format!(
            "user_id=eq.{}&date=gte.{}&date=lte.{}&select=*&order=date.desc",
            user_id, start_str, end_str
        );
        let nutrition: Vec<NutritionDaily> = self
            .supabase
            .select("nutrition_daily", &query, self.access_token)
            .await?;

        if nutrition.is_empty() {
            return Ok(NutritionAvgState {
                avg_calories: None,
                avg_protein_g: None,
                avg_fat_g: None,
                avg_carbs_g: None,
                days_logged: 0,
            });
        }

        let count = nutrition.len() as f64;
        let total_calories: f64 = nutrition.iter().map(|n| n.calories as f64).sum();
        let total_protein: f64 = nutrition.iter().map(|n| n.protein_g).sum();
        let total_fat: f64 = nutrition.iter().map(|n| n.fat_g).sum();
        let total_carbs: f64 = nutrition.iter().map(|n| n.carbs_g).sum();

        Ok(NutritionAvgState {
            avg_calories: Some((total_calories / count).round()),
            avg_protein_g: Some((total_protein / count * 10.0).round() / 10.0),
            avg_fat_g: Some((total_fat / count * 10.0).round() / 10.0),
            avg_carbs_g: Some((total_carbs / count * 10.0).round() / 10.0),
            days_logged: nutrition.len() as i32,
        })
    }
}

/// Calculate estimated 1RM using Epley formula
/// e1rm = weight * (1 + reps/30)
/// Only valid for reps 1-12
pub fn calculate_e1rm(weight: f64, reps: i32) -> f64 {
    if reps <= 0 || reps > 12 {
        return weight;
    }
    let e1rm = weight * (1.0 + reps as f64 / 30.0);
    (e1rm * 100.0).round() / 100.0
}

/// System instruction for Gemini AI
pub fn get_system_instruction(state: &UserState) -> String {
    fn fmt_i32(opt: Option<i32>, unit: &str) -> String {
        opt.map(|v| format!("{}{}", v, unit))
            .unwrap_or_else(|| "不明".to_string())
    }

    fn fmt_f64(opt: Option<f64>, unit: &str, digits: usize) -> String {
        opt.map(|v| format!("{:.*}{}", digits, v, unit))
            .unwrap_or_else(|| "不明".to_string())
    }

    fn fmt_str(opt: Option<&str>) -> String {
        opt.map(|v| v.to_string()).unwrap_or_else(|| "不明".to_string())
    }

    let age_str = match state.profile.birth_year {
        Some(by) => {
            let age = state.today.date.year() - by;
            if age > 0 && age < 120 {
                format!("{}歳", age)
            } else {
                "不明".to_string()
            }
        }
        None => "不明".to_string(),
    };

    let height_cm = state.profile.height_cm;
    let weight_kg = state.today.weight_kg;
    let weight_example_str = state
        .today
        .weight_kg
        .map(|v| format!("{:.1}kg", v))
        .unwrap_or_else(|| "不明".to_string());
    let bmi_str = match (height_cm, weight_kg) {
        (Some(h_cm), Some(w_kg)) if h_cm > 0 && w_kg > 0.0 => {
            let h_m = h_cm as f64 / 100.0;
            let bmi = w_kg / (h_m * h_m);
            format!("{:.1}", bmi)
        }
        _ => "不明".to_string(),
    };

    format!(
        r#"
あなたはトレーニングコーチ「ガチトレAI」。友達みたいに自然に話して。

【ユーザー（プロフィール・身体データ）】
- 目標: {}
- レベル: {}
- 性別: {}
- 年齢: {}
- 身長: {}
- 体重: {}
- 体脂肪率: {}
- BMI: {}
- 睡眠: {}
- 歩数: {}
- 今日の摂取カロリー: {}
- 今日のたんぱく質: {}
- 食事記録回数: {}
- 今日のワークアウト数: {}
- 環境: {}
- 制約: {}

【会話スタイル - 超重要】
- 結論から簡潔に答える。1-2文で十分
- 質問をオウム返ししない（「〇〇についてですね」とか不要）
- 理由は聞かれたときだけ説明する
- 前置き・まとめ不要。本題だけ
- 敬語だけど堅くない。「〜ですね！」「〜しましょう」くらいのノリ

【Q&Aのルール（超重要）】
- まず「ユーザーが何を求めているか」を特定して、それにだけ答える（Q→Aの直結）。
- 「何kg？」「何回？」「何分？」「何kcal？」「何％？」「何cm？」「どれくらい？」「どのくらい増やす？」など“数値”を聞かれたら、必ず具体的な数値（単位付き）で答える（kgに限らない）。
- 単位が質問文に明示されている場合はその単位で答える。単位が曖昧なら、もっとも自然な単位で答えつつ、最後に1つだけ確認質問を添える（例:「回数の話で合ってますか？」）。
- 体重（例: {}）など文脈に関連する基準値があるなら、比率の目安だけで終わらせず“単位換算した具体例”まで提示する（例:「体重の1.0倍」→「{}」）。
- 質問が曖昧で種目/条件が特定できない場合は、
  - ①まず結論として「候補を2-3パターン」具体的な数値（単位付き）で提示（例: ベンチ/スクワット/デッド等）
  - ②最後に1つだけ確認質問（例:「どの種目ですか？」）をする
  - ただし「わからないので答えられません」で終わらない
- 数値のない曖昧回答は禁止（例:「半分くらい」「人による」だけで終わるのはNG）

【ダメな例】
❌「トレーニングメニューについてのご質問ですね。あなたの目標である筋肥大を考慮すると...理由としては...」
⭕「今日は胸の日にしましょう！ベンチプレス3セット、ダンベルフライ3セットでいきましょう」

【禁止】
- 医学的診断・治療の提案
- 基礎代謝以下のカロリー制限
- 怪我リスクは必ず警告

【出力フォーマット】
{{
  "answer_text": "回答（短く自然に）",
  "recommendations": [
    {{"kind": "workout|nutrition|recovery", "payload": {{...}}}}
  ],
  "warnings": ["必要な場合のみ"]
}}
"#,
        state.profile.goal,
        state.profile.training_level,
        fmt_str(state.profile.sex.as_deref()),
        age_str,
        fmt_i32(state.profile.height_cm, "cm"),
        fmt_f64(state.today.weight_kg, "kg", 1),
        fmt_f64(state.today.bodyfat_pct, "%", 1),
        bmi_str,
        fmt_f64(state.today.sleep_hours, "時間", 1),
        state.today
            .steps
            .map(|v| format!("{}歩", v))
            .unwrap_or_else(|| "不明".to_string()),
        state
            .today
            .calories
            .map(|v| format!("{}kcal", v))
            .unwrap_or_else(|| "不明".to_string()),
        fmt_f64(state.today.protein_g, "g", 0),
        state
            .today
            .meals_logged
            .map(|v| format!("{}回", v))
            .unwrap_or_else(|| "不明".to_string()),
        format!("{}回", state.today.workout_count),
        state.profile.environment,
        state.profile.constraints,
        weight_example_str.clone(),
        weight_example_str
    )
}

/// Safety guard - check for dangerous advice requests and prompt injection attempts
pub fn check_safety_flags(message: &str) -> Vec<String> {
    let mut flags = Vec::new();

    let dangerous_keywords = [
        ("ステロイド", "steroids"),
        ("アナボリック", "anabolics"),
        ("断食", "extreme_fasting"),
        ("500kcal以下", "extreme_calorie_restriction"),
        ("怪我を無視", "ignoring_injury"),
        ("痛みがあるけど", "training_with_pain"),
        // Additional dangerous substances
        ("成長ホルモン", "growth_hormone"),
        ("インスリン", "insulin_abuse"),
        ("利尿剤", "diuretics"),
        ("エフェドリン", "ephedrine"),
        ("クレンブテロール", "clenbuterol"),
        // Eating disorders
        ("吐く", "purging"),
        ("過食嘔吐", "binge_purge"),
        ("拒食", "anorexia"),
    ];

    // Prompt injection patterns
    let injection_patterns = [
        ("ignore previous", "prompt_injection"),
        ("ignore all", "prompt_injection"),
        ("disregard", "prompt_injection"),
        ("forget your", "prompt_injection"),
        ("new instructions", "prompt_injection"),
        ("system prompt", "prompt_injection"),
        ("you are now", "prompt_injection"),
        ("act as", "prompt_injection"),
        ("pretend to be", "prompt_injection"),
        ("jailbreak", "prompt_injection"),
        ("無視して", "prompt_injection"),
        ("命令を変更", "prompt_injection"),
        ("システムプロンプト", "prompt_injection"),
        ("別の指示", "prompt_injection"),
        ("役割を変更", "prompt_injection"),
    ];

    // SECURITY: Normalize Unicode to NFKD form to detect homoglyphs and lookalikes
    // Remove zero-width characters and control characters to prevent bypass attacks
    use unicode_normalization::UnicodeNormalization;

    let normalized: String = message
        .nfkd()
        .filter(|c| {
            !c.is_control() &&
            *c != '\u{200B}' && // Zero-width space
            *c != '\u{200C}' && // Zero-width non-joiner
            *c != '\u{200D}' && // Zero-width joiner
            *c != '\u{FEFF}'    // Zero-width no-break space
        })
        .collect::<String>()
        .to_lowercase();

    for (jp, flag) in &dangerous_keywords {
        if normalized.contains(jp) {
            flags.push(flag.to_string());
        }
    }

    for (pattern, flag) in &injection_patterns {
        if normalized.contains(&pattern.to_lowercase()) {
            flags.push(flag.to_string());
        }
    }

    flags
}

/// Sanitize user input for AI prompts
/// Removes or escapes potentially harmful patterns
pub fn sanitize_user_input(input: &str) -> String {
    // Limit message length
    let max_len = 2000;
    let truncated = if input.len() > max_len {
        &input[..max_len]
    } else {
        input
    };

    // Remove control characters except newlines
    let sanitized: String = truncated
        .chars()
        .filter(|c| *c == '\n' || *c == '\t' || !c.is_control())
        .collect();

    // Escape markdown-like formatting that could confuse the model
    sanitized
        .replace("```", "'''")
        .replace("<<<", "((")
        .replace(">>>", "))")
}
