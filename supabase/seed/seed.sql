-- =============================================================================
-- Seed Data: システム種目マスタ (exercises)
-- =============================================================================

-- 既存のシステム種目を削除（重複防止）
DELETE FROM public.exercises WHERE is_system = TRUE;

INSERT INTO public.exercises (name, name_en, primary_muscle, secondary_muscles, equipment, is_system) VALUES
-- ============================================
-- 胸 (chest) - 20種目
-- ============================================
('ベンチプレス', 'Bench Press', 'chest', ARRAY['triceps', 'shoulder'], 'barbell', TRUE),
('ダンベルプレス', 'Dumbbell Press', 'chest', ARRAY['triceps', 'shoulder'], 'dumbbell', TRUE),
('インクラインベンチプレス', 'Incline Bench Press', 'chest', ARRAY['triceps', 'shoulder'], 'barbell', TRUE),
('インクラインダンベルプレス', 'Incline Dumbbell Press', 'chest', ARRAY['triceps', 'shoulder'], 'dumbbell', TRUE),
('デクラインベンチプレス', 'Decline Bench Press', 'chest', ARRAY['triceps'], 'barbell', TRUE),
('デクラインダンベルプレス', 'Decline Dumbbell Press', 'chest', ARRAY['triceps'], 'dumbbell', TRUE),
('ダンベルフライ', 'Dumbbell Fly', 'chest', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('インクラインダンベルフライ', 'Incline Dumbbell Fly', 'chest', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ケーブルクロスオーバー', 'Cable Crossover', 'chest', ARRAY[]::TEXT[], 'cable', TRUE),
('ロープレスケーブルフライ', 'Low Cable Fly', 'chest', ARRAY[]::TEXT[], 'cable', TRUE),
('ハイケーブルフライ', 'High Cable Fly', 'chest', ARRAY[]::TEXT[], 'cable', TRUE),
('チェストプレス', 'Chest Press Machine', 'chest', ARRAY['triceps'], 'machine', TRUE),
('ペックデック', 'Pec Deck', 'chest', ARRAY[]::TEXT[], 'machine', TRUE),
('スミスマシンベンチプレス', 'Smith Machine Bench Press', 'chest', ARRAY['triceps', 'shoulder'], 'machine', TRUE),
('腕立て伏せ', 'Push Up', 'chest', ARRAY['triceps', 'shoulder'], 'bodyweight', TRUE),
('ワイドプッシュアップ', 'Wide Push Up', 'chest', ARRAY['triceps'], 'bodyweight', TRUE),
('ディップス', 'Dips', 'chest', ARRAY['triceps'], 'bodyweight', TRUE),
('ダンベルプルオーバー', 'Dumbbell Pullover', 'chest', ARRAY['back'], 'dumbbell', TRUE),
('フロアプレス', 'Floor Press', 'chest', ARRAY['triceps'], 'barbell', TRUE),
('スヴェンドプレス', 'Svend Press', 'chest', ARRAY[]::TEXT[], 'dumbbell', TRUE),

-- ============================================
-- 背中 (back) - 22種目
-- ============================================
('デッドリフト', 'Deadlift', 'back', ARRAY['hamstrings', 'glutes'], 'barbell', TRUE),
('ラットプルダウン', 'Lat Pulldown', 'back', ARRAY['biceps'], 'cable', TRUE),
('ワイドグリップラットプルダウン', 'Wide Grip Lat Pulldown', 'back', ARRAY['biceps'], 'cable', TRUE),
('クローズグリップラットプルダウン', 'Close Grip Lat Pulldown', 'back', ARRAY['biceps'], 'cable', TRUE),
('ビハインドネックラットプルダウン', 'Behind Neck Lat Pulldown', 'back', ARRAY['biceps'], 'cable', TRUE),
('チンニング', 'Chin Up', 'back', ARRAY['biceps'], 'bodyweight', TRUE),
('懸垂', 'Pull Up', 'back', ARRAY['biceps'], 'bodyweight', TRUE),
('ワイドグリップ懸垂', 'Wide Grip Pull Up', 'back', ARRAY['biceps'], 'bodyweight', TRUE),
('ベントオーバーロウ', 'Bent Over Row', 'back', ARRAY['biceps'], 'barbell', TRUE),
('ダンベルロウ', 'Dumbbell Row', 'back', ARRAY['biceps'], 'dumbbell', TRUE),
('ワンアームダンベルロウ', 'One Arm Dumbbell Row', 'back', ARRAY['biceps'], 'dumbbell', TRUE),
('シーテッドロウ', 'Seated Row', 'back', ARRAY['biceps'], 'cable', TRUE),
('ケーブルロウ', 'Cable Row', 'back', ARRAY['biceps'], 'cable', TRUE),
('Tバーロウ', 'T-Bar Row', 'back', ARRAY['biceps'], 'barbell', TRUE),
('ペンドレイロウ', 'Pendlay Row', 'back', ARRAY['biceps'], 'barbell', TRUE),
('マシンロウ', 'Machine Row', 'back', ARRAY['biceps'], 'machine', TRUE),
('ストレートアームプルダウン', 'Straight Arm Pulldown', 'back', ARRAY[]::TEXT[], 'cable', TRUE),
('シールロウ', 'Seal Row', 'back', ARRAY['biceps'], 'barbell', TRUE),
('インバーテッドロウ', 'Inverted Row', 'back', ARRAY['biceps'], 'bodyweight', TRUE),
('ケーブルプルオーバー', 'Cable Pullover', 'back', ARRAY['chest'], 'cable', TRUE),
('シュラッグ', 'Shrug', 'back', ARRAY[]::TEXT[], 'barbell', TRUE),
('ダンベルシュラッグ', 'Dumbbell Shrug', 'back', ARRAY[]::TEXT[], 'dumbbell', TRUE),

-- ============================================
-- 肩 (shoulder) - 18種目
-- ============================================
('オーバーヘッドプレス', 'Overhead Press', 'shoulder', ARRAY['triceps'], 'barbell', TRUE),
('ダンベルショルダープレス', 'Dumbbell Shoulder Press', 'shoulder', ARRAY['triceps'], 'dumbbell', TRUE),
('アーノルドプレス', 'Arnold Press', 'shoulder', ARRAY['triceps'], 'dumbbell', TRUE),
('シーテッドショルダープレス', 'Seated Shoulder Press', 'shoulder', ARRAY['triceps'], 'barbell', TRUE),
('マシンショルダープレス', 'Machine Shoulder Press', 'shoulder', ARRAY['triceps'], 'machine', TRUE),
('スミスマシンショルダープレス', 'Smith Machine Shoulder Press', 'shoulder', ARRAY['triceps'], 'machine', TRUE),
('プッシュプレス', 'Push Press', 'shoulder', ARRAY['triceps', 'quadriceps'], 'barbell', TRUE),
('サイドレイズ', 'Lateral Raise', 'shoulder', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ケーブルサイドレイズ', 'Cable Lateral Raise', 'shoulder', ARRAY[]::TEXT[], 'cable', TRUE),
('マシンサイドレイズ', 'Machine Lateral Raise', 'shoulder', ARRAY[]::TEXT[], 'machine', TRUE),
('フロントレイズ', 'Front Raise', 'shoulder', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ケーブルフロントレイズ', 'Cable Front Raise', 'shoulder', ARRAY[]::TEXT[], 'cable', TRUE),
('プレートフロントレイズ', 'Plate Front Raise', 'shoulder', ARRAY[]::TEXT[], 'barbell', TRUE),
('リアデルトフライ', 'Rear Delt Fly', 'shoulder', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('リアデルトマシン', 'Rear Delt Machine', 'shoulder', ARRAY[]::TEXT[], 'machine', TRUE),
('フェイスプル', 'Face Pull', 'shoulder', ARRAY[]::TEXT[], 'cable', TRUE),
('アップライトロウ', 'Upright Row', 'shoulder', ARRAY['biceps'], 'barbell', TRUE),
('ケーブルアップライトロウ', 'Cable Upright Row', 'shoulder', ARRAY['biceps'], 'cable', TRUE),

-- ============================================
-- 上腕二頭筋 (biceps) - 15種目
-- ============================================
('バーベルカール', 'Barbell Curl', 'biceps', ARRAY[]::TEXT[], 'barbell', TRUE),
('EZバーカール', 'EZ Bar Curl', 'biceps', ARRAY[]::TEXT[], 'barbell', TRUE),
('ダンベルカール', 'Dumbbell Curl', 'biceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('オルタネイトダンベルカール', 'Alternate Dumbbell Curl', 'biceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ハンマーカール', 'Hammer Curl', 'biceps', ARRAY['forearm'], 'dumbbell', TRUE),
('プリーチャーカール', 'Preacher Curl', 'biceps', ARRAY[]::TEXT[], 'barbell', TRUE),
('ダンベルプリーチャーカール', 'Dumbbell Preacher Curl', 'biceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('インクラインカール', 'Incline Curl', 'biceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('コンセントレーションカール', 'Concentration Curl', 'biceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ケーブルカール', 'Cable Curl', 'biceps', ARRAY[]::TEXT[], 'cable', TRUE),
('ハイケーブルカール', 'High Cable Curl', 'biceps', ARRAY[]::TEXT[], 'cable', TRUE),
('マシンカール', 'Machine Curl', 'biceps', ARRAY[]::TEXT[], 'machine', TRUE),
('スパイダーカール', 'Spider Curl', 'biceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ドラッグカール', 'Drag Curl', 'biceps', ARRAY[]::TEXT[], 'barbell', TRUE),
('21カール', '21s Curl', 'biceps', ARRAY[]::TEXT[], 'barbell', TRUE),

-- ============================================
-- 上腕三頭筋 (triceps) - 15種目
-- ============================================
('トライセプスプッシュダウン', 'Triceps Pushdown', 'triceps', ARRAY[]::TEXT[], 'cable', TRUE),
('ロープトライセプスプッシュダウン', 'Rope Triceps Pushdown', 'triceps', ARRAY[]::TEXT[], 'cable', TRUE),
('Vバートライセプスプッシュダウン', 'V-Bar Triceps Pushdown', 'triceps', ARRAY[]::TEXT[], 'cable', TRUE),
('スカルクラッシャー', 'Skull Crusher', 'triceps', ARRAY[]::TEXT[], 'barbell', TRUE),
('ダンベルスカルクラッシャー', 'Dumbbell Skull Crusher', 'triceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('オーバーヘッドエクステンション', 'Overhead Extension', 'triceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ケーブルオーバーヘッドエクステンション', 'Cable Overhead Extension', 'triceps', ARRAY[]::TEXT[], 'cable', TRUE),
('キックバック', 'Kickback', 'triceps', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('ケーブルキックバック', 'Cable Kickback', 'triceps', ARRAY[]::TEXT[], 'cable', TRUE),
('クローズグリップベンチプレス', 'Close Grip Bench Press', 'triceps', ARRAY['chest'], 'barbell', TRUE),
('ダイヤモンドプッシュアップ', 'Diamond Push Up', 'triceps', ARRAY['chest'], 'bodyweight', TRUE),
('トライセプスディップス', 'Triceps Dips', 'triceps', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('ベンチディップス', 'Bench Dips', 'triceps', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('JMプレス', 'JM Press', 'triceps', ARRAY['chest'], 'barbell', TRUE),
('トライセプスマシン', 'Triceps Machine', 'triceps', ARRAY[]::TEXT[], 'machine', TRUE),

-- ============================================
-- 前腕 (forearm) - 8種目
-- ============================================
('リストカール', 'Wrist Curl', 'forearm', ARRAY[]::TEXT[], 'barbell', TRUE),
('ダンベルリストカール', 'Dumbbell Wrist Curl', 'forearm', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('リバースリストカール', 'Reverse Wrist Curl', 'forearm', ARRAY[]::TEXT[], 'barbell', TRUE),
('リバースカール', 'Reverse Curl', 'forearm', ARRAY['biceps'], 'barbell', TRUE),
('ダンベルリバースカール', 'Dumbbell Reverse Curl', 'forearm', ARRAY['biceps'], 'dumbbell', TRUE),
('ファーマーズウォーク', 'Farmers Walk', 'forearm', ARRAY['back'], 'dumbbell', TRUE),
('プレートピンチ', 'Plate Pinch', 'forearm', ARRAY[]::TEXT[], 'barbell', TRUE),
('グリッパー', 'Hand Gripper', 'forearm', ARRAY[]::TEXT[], 'bodyweight', TRUE),

-- ============================================
-- 脚・大腿四頭筋 (quadriceps) - 15種目
-- ============================================
('スクワット', 'Squat', 'quadriceps', ARRAY['glutes', 'hamstrings'], 'barbell', TRUE),
('フロントスクワット', 'Front Squat', 'quadriceps', ARRAY['glutes'], 'barbell', TRUE),
('ハイバースクワット', 'High Bar Squat', 'quadriceps', ARRAY['glutes', 'hamstrings'], 'barbell', TRUE),
('ローバースクワット', 'Low Bar Squat', 'quadriceps', ARRAY['glutes', 'hamstrings'], 'barbell', TRUE),
('レッグプレス', 'Leg Press', 'quadriceps', ARRAY['glutes'], 'machine', TRUE),
('ナローレッグプレス', 'Narrow Leg Press', 'quadriceps', ARRAY[]::TEXT[], 'machine', TRUE),
('レッグエクステンション', 'Leg Extension', 'quadriceps', ARRAY[]::TEXT[], 'machine', TRUE),
('ブルガリアンスクワット', 'Bulgarian Split Squat', 'quadriceps', ARRAY['glutes'], 'dumbbell', TRUE),
('ハックスクワット', 'Hack Squat', 'quadriceps', ARRAY['glutes'], 'machine', TRUE),
('ゴブレットスクワット', 'Goblet Squat', 'quadriceps', ARRAY['glutes'], 'dumbbell', TRUE),
('ランジ', 'Lunge', 'quadriceps', ARRAY['glutes'], 'bodyweight', TRUE),
('ウォーキングランジ', 'Walking Lunge', 'quadriceps', ARRAY['glutes'], 'dumbbell', TRUE),
('リバースランジ', 'Reverse Lunge', 'quadriceps', ARRAY['glutes'], 'dumbbell', TRUE),
('シシースクワット', 'Sissy Squat', 'quadriceps', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('ステップアップ', 'Step Up', 'quadriceps', ARRAY['glutes'], 'dumbbell', TRUE),

-- ============================================
-- 脚・ハムストリングス (hamstrings) - 10種目
-- ============================================
('レッグカール', 'Leg Curl', 'hamstrings', ARRAY[]::TEXT[], 'machine', TRUE),
('シーテッドレッグカール', 'Seated Leg Curl', 'hamstrings', ARRAY[]::TEXT[], 'machine', TRUE),
('ライイングレッグカール', 'Lying Leg Curl', 'hamstrings', ARRAY[]::TEXT[], 'machine', TRUE),
('ルーマニアンデッドリフト', 'Romanian Deadlift', 'hamstrings', ARRAY['glutes'], 'barbell', TRUE),
('ダンベルルーマニアンデッドリフト', 'Dumbbell Romanian Deadlift', 'hamstrings', ARRAY['glutes'], 'dumbbell', TRUE),
('スティッフレッグデッドリフト', 'Stiff Leg Deadlift', 'hamstrings', ARRAY['glutes'], 'barbell', TRUE),
('グッドモーニング', 'Good Morning', 'hamstrings', ARRAY['back'], 'barbell', TRUE),
('ノルディックハムカール', 'Nordic Ham Curl', 'hamstrings', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('グルートハムレイズ', 'Glute Ham Raise', 'hamstrings', ARRAY['glutes'], 'bodyweight', TRUE),
('ケーブルプルスルー', 'Cable Pull Through', 'hamstrings', ARRAY['glutes'], 'cable', TRUE),

-- ============================================
-- 臀部 (glutes) - 12種目
-- ============================================
('ヒップスラスト', 'Hip Thrust', 'glutes', ARRAY['hamstrings'], 'barbell', TRUE),
('ダンベルヒップスラスト', 'Dumbbell Hip Thrust', 'glutes', ARRAY['hamstrings'], 'dumbbell', TRUE),
('シングルレッグヒップスラスト', 'Single Leg Hip Thrust', 'glutes', ARRAY['hamstrings'], 'bodyweight', TRUE),
('グルートブリッジ', 'Glute Bridge', 'glutes', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('シングルレッググルートブリッジ', 'Single Leg Glute Bridge', 'glutes', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('ケーブルヒップアブダクション', 'Cable Hip Abduction', 'glutes', ARRAY[]::TEXT[], 'cable', TRUE),
('マシンヒップアブダクション', 'Machine Hip Abduction', 'glutes', ARRAY[]::TEXT[], 'machine', TRUE),
('マシンヒップアダクション', 'Machine Hip Adduction', 'glutes', ARRAY[]::TEXT[], 'machine', TRUE),
('ドンキーキック', 'Donkey Kick', 'glutes', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('ファイヤーハイドラント', 'Fire Hydrant', 'glutes', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('クラムシェル', 'Clamshell', 'glutes', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('スモウデッドリフト', 'Sumo Deadlift', 'glutes', ARRAY['hamstrings', 'quadriceps'], 'barbell', TRUE),

-- ============================================
-- ふくらはぎ (calves) - 8種目
-- ============================================
('スタンディングカーフレイズ', 'Standing Calf Raise', 'calves', ARRAY[]::TEXT[], 'machine', TRUE),
('シーテッドカーフレイズ', 'Seated Calf Raise', 'calves', ARRAY[]::TEXT[], 'machine', TRUE),
('レッグプレスカーフレイズ', 'Leg Press Calf Raise', 'calves', ARRAY[]::TEXT[], 'machine', TRUE),
('ドンキーカーフレイズ', 'Donkey Calf Raise', 'calves', ARRAY[]::TEXT[], 'machine', TRUE),
('スミスマシンカーフレイズ', 'Smith Machine Calf Raise', 'calves', ARRAY[]::TEXT[], 'machine', TRUE),
('ダンベルカーフレイズ', 'Dumbbell Calf Raise', 'calves', ARRAY[]::TEXT[], 'dumbbell', TRUE),
('シングルレッグカーフレイズ', 'Single Leg Calf Raise', 'calves', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('バーベルカーフレイズ', 'Barbell Calf Raise', 'calves', ARRAY[]::TEXT[], 'barbell', TRUE),

-- ============================================
-- 腹筋・コア (abs) - 20種目
-- ============================================
('クランチ', 'Crunch', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('シットアップ', 'Sit Up', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('リバースクランチ', 'Reverse Crunch', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('バイシクルクランチ', 'Bicycle Crunch', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('レッグレイズ', 'Leg Raise', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('ハンギングレッグレイズ', 'Hanging Leg Raise', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('ハンギングニーレイズ', 'Hanging Knee Raise', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('キャプテンズチェアレッグレイズ', 'Captains Chair Leg Raise', 'abs', ARRAY[]::TEXT[], 'machine', TRUE),
('プランク', 'Plank', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('サイドプランク', 'Side Plank', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('デッドバグ', 'Dead Bug', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('マウンテンクライマー', 'Mountain Climber', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('アブローラー', 'Ab Roller', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('ケーブルクランチ', 'Cable Crunch', 'abs', ARRAY[]::TEXT[], 'cable', TRUE),
('ウッドチョップ', 'Wood Chop', 'abs', ARRAY[]::TEXT[], 'cable', TRUE),
('ロシアンツイスト', 'Russian Twist', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('Vアップ', 'V Up', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('トーズトゥバー', 'Toes to Bar', 'abs', ARRAY[]::TEXT[], 'bodyweight', TRUE),
('アブマシン', 'Ab Machine', 'abs', ARRAY[]::TEXT[], 'machine', TRUE),
('パロフプレス', 'Pallof Press', 'abs', ARRAY[]::TEXT[], 'cable', TRUE);

-- 確認用: 追加された種目数を表示
SELECT 
    primary_muscle as "部位",
    COUNT(*) as "種目数"
FROM public.exercises 
WHERE is_system = TRUE
GROUP BY primary_muscle
ORDER BY primary_muscle;

