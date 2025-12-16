// Domain services
// Business logic that doesn't fit into handlers or infrastructure

use crate::state::calculate_e1rm;

/// Calculate recommended weight for next set based on previous performance
pub fn calculate_progression(
    current_weight: f64,
    current_reps: i32,
    target_reps_min: i32,
    target_reps_max: i32,
) -> ProgressionRecommendation {
    let current_e1rm = calculate_e1rm(current_weight, current_reps);

    // If reps are above target max, increase weight
    if current_reps > target_reps_max {
        let weight_increase = current_weight * 0.05; // 5% increase
        let new_weight = (current_weight + weight_increase).round();
        return ProgressionRecommendation {
            suggested_weight: new_weight,
            suggested_reps: format!("{}-{}", target_reps_min, target_reps_max),
            reason: "目標レップを超えたので、重量を増やしましょう".to_string(),
        };
    }

    // If reps are below target min, maintain or decrease weight
    if current_reps < target_reps_min {
        return ProgressionRecommendation {
            suggested_weight: current_weight,
            suggested_reps: format!("{}-{}", target_reps_min, target_reps_max),
            reason: "目標レップに達していないので、同じ重量で練習しましょう".to_string(),
        };
    }

    // Reps are in target range, maintain weight
    ProgressionRecommendation {
        suggested_weight: current_weight,
        suggested_reps: format!("{}-{}", target_reps_min, target_reps_max),
        reason: "良いペースです。この重量を維持しましょう".to_string(),
    }
}

#[derive(Debug)]
pub struct ProgressionRecommendation {
    pub suggested_weight: f64,
    pub suggested_reps: String,
    pub reason: String,
}

/// Calculate daily calorie target based on goal and body metrics
pub fn calculate_calorie_target(
    weight_kg: f64,
    height_cm: i32,
    age: i32,
    sex: &str,
    activity_level: f64, // 1.2 sedentary, 1.375 light, 1.55 moderate, 1.725 active, 1.9 very active
    goal: &str,
) -> CalorieTarget {
    // Mifflin-St Jeor equation for BMR
    let bmr = if sex == "male" {
        10.0 * weight_kg + 6.25 * height_cm as f64 - 5.0 * age as f64 + 5.0
    } else {
        10.0 * weight_kg + 6.25 * height_cm as f64 - 5.0 * age as f64 - 161.0
    };

    let tdee = bmr * activity_level;

    let (calories, protein_g, description) = match goal {
        "cut" => {
            // 20% deficit
            let cal = (tdee * 0.8).round() as i32;
            let protein = weight_kg * 2.2; // Higher protein for muscle retention
            (cal, protein, "減量目標（20%カロリー制限）")
        }
        "hypertrophy" => {
            // 10-15% surplus
            let cal = (tdee * 1.12).round() as i32;
            let protein = weight_kg * 1.8;
            (cal, protein, "筋肥大目標（12%カロリー増加）")
        }
        "strength" => {
            // 5-10% surplus
            let cal = (tdee * 1.07).round() as i32;
            let protein = weight_kg * 2.0;
            (cal, protein, "筋力向上目標（7%カロリー増加）")
        }
        _ => {
            // Maintenance
            let cal = tdee.round() as i32;
            let protein = weight_kg * 1.6;
            (cal, protein, "健康維持目標")
        }
    };

    CalorieTarget {
        calories,
        protein_g: protein_g.round() as i32,
        fat_g: ((calories as f64 * 0.25) / 9.0).round() as i32, // 25% from fat
        carbs_g: ((calories as f64 - protein_g * 4.0 - (calories as f64 * 0.25)) / 4.0).round() as i32,
        description: description.to_string(),
    }
}

#[derive(Debug)]
pub struct CalorieTarget {
    pub calories: i32,
    pub protein_g: i32,
    pub fat_g: i32,
    pub carbs_g: i32,
    pub description: String,
}
