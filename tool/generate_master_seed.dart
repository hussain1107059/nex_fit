// Regenerates supabase/migrations/002_master_seed.sql from the real Dart seed
// sources so the cloud catalog always matches what the app ships locally:
//
//   * foods  -> lib/data/services/food_seed_data.dart   (212 rows)
//   * exercises -> lib/data/datasources/local/workout_seed_data.dart (83 rows)
//   * workout templates + links -> the same file       (26 workouts / 147 links)
//   * workout_categories, meal_categories, goal_templates -> extracted from the
//     seed SQL inside lib/data/datasources/local/app_database.dart
//   * achievement_defs, badge_defs -> extracted from
//     lib/data/repositories/workout_session_repository_impl.dart
//
// Run:  dart run tool/generate_master_seed.dart
// The generator never writes to the DB; it only emits a deterministic,
// idempotent SQL migration file.
import 'dart:io';

import 'package:nexfit/data/datasources/local/workout_seed_data.dart';
import 'package:nexfit/data/services/food_seed_data.dart';

void main() {
  final StringBuffer out = StringBuffer();

  out.writeln(
    '-- =============================================================================\n'
    '-- NexFit - Master/Reference Data Seed\n'
    '-- =============================================================================\n'
    '-- Migration : 002_master_seed.sql\n'
    '-- Project   : NexFit (Flutter, offline-first, two-way sync)\n'
    '-- Phase     : 03 - seed data for the global catalogs\n'
    '--\n'
    '-- Source of truth : tool/generate_master_seed.dart reads the app seed data\n'
    '--                   and regenerates this file. Do not hand-edit the data rows.\n'
    '--\n'
    '-- Idempotency     : every INSERT uses ON CONFLICT DO NOTHING against the\n'
    '--                   unique indexes defined in migration 001 (and the two\n'
    '--                   template constraints added below), so re-running this\n'
    '--                   migration is a no-op for existing rows.\n'
    '--\n'
    '-- Versioning      : master catalogs are bulk-synced by the mobile client via\n'
    '--                   public.master_data_versions. The final SELECT statements\n'
    '--                   bump each catalog cursor so clients pull the new rows.\n'
    '--\n'
    '-- Rows            : ${kSeedFoods.length} foods, ${kSeedExercises.length} exercises,\n'
    '--                   ${kSeedWorkouts.length} workout templates, '
    '${kSeedWorkouts.fold<int>(0, (n, w) => n + w.exercises.length)} template links,\n'
    '--                   21 workout categories, 6 meal categories, 4 goal templates,\n'
    '--                   7 achievements, 8 badges.\n'
    '-- =============================================================================',
  );

  // ---------------------------------------------------------------------------
  // Complementary unique constraints so the seed is idempotent. These are pure
  // production-safe uniqueness rules (a global template name is unique; a
  // template never contains the same exercise twice) and do not conflict with
  // migration 001.
  // ---------------------------------------------------------------------------
  out.writeln('''
-- 0. Complementary unique constraints for idempotent template seeding
create unique index if not exists uq_workout_templates_name
    on public.workout_templates (name);
create unique index if not exists uq_workout_template_exercises_pair
    on public.workout_template_exercises (template_id, exercise_id);
''');

  // ---------------------------------------------------------------------------
  // Meal categories (6) - app_database.dart _insertSeedData + v6 nutrition
  // ---------------------------------------------------------------------------
  out.writeln('''
-- -----------------------------------------------------------------------------
-- 1. meal_categories (6 global meal slots)
-- -----------------------------------------------------------------------------
insert into public.meal_categories (name, slug, icon, sort_order)
values
  ('Breakfast', 'breakfast', NULL, 1),
  ('Morning Snack', 'morning_snack', NULL, 2),
  ('Lunch', 'lunch', NULL, 3),
  ('Evening Snack', 'evening_snack', NULL, 4),
  ('Dinner', 'dinner', NULL, 5),
  ('Late Night Snack', 'late_night_snack', NULL, 6)
on conflict (slug) do nothing;
''');

  // ---------------------------------------------------------------------------
  // Goal templates (4) - app_database.dart _insertSeedData
  // ---------------------------------------------------------------------------
  out.writeln('''
-- -----------------------------------------------------------------------------
-- 2. goal_templates (4 global fitness-goal templates)
-- -----------------------------------------------------------------------------
insert into public.goal_templates (goal_type, title, description, status)
values
  ('weight_loss', 'Weight Loss', 'Gradually lose body weight', 'active'),
  ('weight_gain', 'Weight Gain', 'Gain healthy body weight', 'active'),
  ('maintain_weight', 'Maintain Weight', 'Keep current body weight stable', 'active'),
  ('muscle_building', 'Muscle Building', 'Build lean muscle mass', 'active')
on conflict (goal_type) do nothing;
''');

  // ---------------------------------------------------------------------------
  // Workout categories (21) - app_database.dart v2/v4 seed SQL
  // ---------------------------------------------------------------------------
  out.writeln('''
-- -----------------------------------------------------------------------------
-- 3. workout_categories (21 global workout categories)
-- -----------------------------------------------------------------------------
insert into public.workout_categories (name, slug, description, icon, color, sort_order)
values
  ('Home Workout', 'home_workout', 'Work out at home with minimal equipment', 'home', 4279148398, 1),
  ('Gym Workout', 'gym_workout', 'Use gym equipment for full training sessions', 'gym', 4285357008, 2),
  ('Cardio', 'cardio', 'Get your heart pumping and burn calories', 'cardio', 4293870660, 3),
  ('Yoga', 'yoga', 'Improve flexibility, balance and mindfulness', 'yoga', 4287323382, 4),
  ('Strength', 'strength', 'Build strength with resistance training', 'strength', 4294538006, 5),
  ('HIIT', 'hiit', 'High intensity interval training for quick results', 'hiit', 4294937088, 6),
  ('Stretching', 'stretching', 'Improve mobility and recover faster', 'stretching', 4279548070, 7),
  ('Full Body', 'full_body', 'Train every major muscle group in one session', 'full_body', 4279148398, 8),
  ('Upper Body', 'upper_body', 'Focus on arms, chest, back and shoulders', 'upper_body', 4282090230, 9),
  ('Lower Body', 'lower_body', 'Build strong legs, glutes and core', 'lower_body', 4294286859, 10),
  ('Chest', 'chest', 'Build a stronger, bigger chest', 'chest', 4293870660, 11),
  ('Back', 'back', 'Strengthen your back and posture', 'back', 4284704497, 12),
  ('Shoulder', 'shoulder', 'Sculpt strong, defined shoulders', 'shoulder', 4282090230, 13),
  ('Arms', 'arms', 'Biceps, triceps and forearm strength', 'arms', 4294538006, 14),
  ('Legs', 'legs', 'Powerful legs with squats and lunges', 'legs', 4287323382, 15),
  ('Core', 'core', 'Strengthen your abs and core stability', 'core', 4293675161, 16),
  ('Fat Loss', 'fat_loss', 'Burn fat with calorie-torching sessions', 'fat_loss', 4294286859, 17),
  ('Muscle Gain', 'muscle_gain', 'Hypertrophy training to build muscle', 'muscle_gain', 4280468830, 18),
  ('Beginner', 'beginner', 'Easy, beginner-friendly workouts', 'beginner', 4279548070, 19),
  ('Intermediate', 'intermediate', 'Moderate workouts for steady progress', 'intermediate', 4282090230, 20),
  ('Advanced', 'advanced', 'Challenging workouts for experienced athletes', 'advanced', 4287323382, 21)
on conflict (slug) do nothing;
''');

  // ---------------------------------------------------------------------------
  // Exercises (83) - workout_seed_data.dart kSeedExercises
  // ---------------------------------------------------------------------------
  out.writeln('''
-- -----------------------------------------------------------------------------
-- 4. exercises (${kSeedExercises.length} global exercises, user_id IS NULL)
-- -----------------------------------------------------------------------------
insert into public.exercises (
    name, scientific_name, description, instructions, body_part, secondary_muscle,
    equipment, difficulty, category, calories_per_minute, estimated_calories,
    duration_seconds, sets, reps, rest_seconds, tips, common_mistakes,
    safety_instructions
)
values
''');

  final Set<String> exerciseNames = <String>{};
  for (final SeedExercise e in kSeedExercises) {
    exerciseNames.add(e.name);
    out.writeln(
      '  (${s(e.name)}, ${s(e.scientificName)}, ${s(e.description)}, '
      '${s(e.instructionsText)}, ${s(e.bodyPart)}, ${s(e.secondaryMuscle)}, '
      '${s(e.equipment)}, ${s(e.difficulty.name)}, ${s(e.category.name)}, '
      '${n(e.caloriesPerMinute)}, ${i(e.estimatedCalories)}, '
      '${i(e.durationSeconds)}, ${i(e.sets)}, ${i(e.reps)}, ${i(e.restSeconds)}, '
      '${s(e.tipsText)}, ${s(e.mistakesText)}, ${s(e.safetyText)}),',
    );
  }
  _trimLastComma(out);
  out.writeln('on conflict (name) where user_id is null do nothing;\n');

  // ---------------------------------------------------------------------------
  // Foods (212) - food_seed_data.dart kSeedFoods
  // ---------------------------------------------------------------------------
  out.writeln('''
-- -----------------------------------------------------------------------------
-- 5. foods (${kSeedFoods.length} global foods, user_id IS NULL)
-- -----------------------------------------------------------------------------
insert into public.foods (
    name, category, serving_size, serving_grams, calories, protein, carbs, fat,
    fiber, sugar, sodium, potassium, calcium, iron, vitamin_a, vitamin_c,
    water_percentage
)
values
''');
  for (final SeedFood f in kSeedFoods) {
    out.writeln(
      '  (${s(f.name)}, ${s(f.category.name)}, ${s(f.servingSize)}, '
      '${n(f.servingGrams)}, ${n(f.calories)}, ${n(f.protein)}, ${n(f.carbs)}, '
      '${n(f.fat)}, ${n(f.fiber)}, ${n(f.sugar)}, ${n(f.sodium)}, ${n(f.potassium)}, '
      '${n(f.calcium)}, ${n(f.iron)}, ${n(f.vitaminA)}, ${n(f.vitaminC)}, '
      '${n(f.waterPercentage)}),',
    );
  }
  _trimLastComma(out);
  out.writeln('on conflict (name) where user_id is null do nothing;\n');

  // ---------------------------------------------------------------------------
  // Workout templates (26) - workout_seed_data.dart kSeedWorkouts
  // ---------------------------------------------------------------------------
  final Set<String> categorySlugs = <String>{
    for (final s in _categoryCatalog) s.slug,
  };
  out.writeln('''
-- -----------------------------------------------------------------------------
-- 6. workout_templates (${kSeedWorkouts.length} global routines)
-- -----------------------------------------------------------------------------
insert into public.workout_templates (
    category_id, name, description, difficulty, duration_minutes, calories_burn
)
select wc.id, v.name, v.description, v.difficulty, v.duration_minutes,
       v.calories_burn
from (values
''');
  for (final SeedWorkout w in kSeedWorkouts) {
    if (!categorySlugs.contains(w.categorySlug)) {
      stderr.writeln(
        'WARNING: workout "${w.name}" references unknown category '
        '"${w.categorySlug}" -> category_id will be NULL',
      );
    }
    out.writeln(
      '  (${s(w.categorySlug)}, ${s(w.name)}, ${s(w.description)}, '
      '${s(w.difficulty.name)}, ${i(w.durationMinutes)}, ${n(w.calories)}),',
    );
  }
  _trimLastComma(out);
  out.writeln('''
) as v(slug, name, description, difficulty, duration_minutes, calories_burn)
left join public.workout_categories wc on wc.slug = v.slug
on conflict (name) do nothing;
''');

  // ---------------------------------------------------------------------------
  // Workout template exercises (147) - name-to-id resolution at insert time
  // ---------------------------------------------------------------------------
  out.writeln('''
-- -----------------------------------------------------------------------------
-- 7. workout_template_exercises (template links)
-- -----------------------------------------------------------------------------
insert into public.workout_template_exercises (
    template_id, exercise_id, sets, reps, duration_seconds, rest_seconds,
    sort_order
)
select t.id, e.id, v.sets, v.reps, v.duration_seconds, v.rest_seconds,
       v.sort_order
from (values
''');
  int missingExercises = 0;
  for (final SeedWorkout w in kSeedWorkouts) {
    int sortOrder = 0;
    for (final SeedWorkoutExercise item in w.exercises) {
      if (!exerciseNames.contains(item.exerciseName)) {
        missingExercises++;
        stderr.writeln(
          'WARNING: workout "${w.name}" references unknown exercise '
          '"${item.exerciseName}" -> link will be skipped',
        );
      }
      out.writeln(
        '  (${s(w.name)}, ${s(item.exerciseName)}, ${i(item.sets)}, '
        '${i(item.reps)}, ${i(item.durationSeconds)}, ${i(item.restSeconds)}, '
        '${i(sortOrder)}),',
      );
      sortOrder++;
    }
  }
  _trimLastComma(out);
  out.writeln('''
) as v(template_name, exercise_name, sets, reps, duration_seconds, rest_seconds,
       sort_order)
join public.workout_templates t on t.name = v.template_name
join public.exercises e on e.name = v.exercise_name and e.user_id is null
on conflict (template_id, exercise_id) do nothing;
''');

  // ---------------------------------------------------------------------------
  // Achievement definitions (7) - workout_session_repository_impl.dart
  // ---------------------------------------------------------------------------
  out.writeln('''
-- -----------------------------------------------------------------------------
-- 8. achievement_defs (7 global achievements)
--    Extracted from WorkoutSessionRepositoryImpl._unlockAchievements().
--    xp_reward is not part of the local model; it defaults to 0 and can be
--    tuned later without touching the app.
-- -----------------------------------------------------------------------------
insert into public.achievement_defs (achievement_type, name, description, icon, xp_reward, sort_order)
values
  ('first_workout', 'First Workout', 'Complete your very first workout session.', 'emoji_events', 0, 1),
  ('workout_count_10', 'Workout Warrior', 'Complete 10 workout sessions.', 'military_tech', 0, 2),
  ('workout_count_50', 'Fitness Freak', 'Complete 50 workout sessions.', 'local_fire_department', 0, 3),
  ('calories_500', 'Calorie Crusher', 'Burn 500 kcal through workouts.', 'bolt', 0, 4),
  ('calories_2000', 'Calorie King', 'Burn 2000 kcal through workouts.', 'whatshot', 0, 5),
  ('streak_7', 'Weekly Warrior', 'Work out for 7 days in a row.', 'calendar_month', 0, 6),
  ('streak_30', 'Monthly Monster', 'Work out for 30 days in a row.', 'workspace_premium', 0, 7)
on conflict (achievement_type) do nothing;
''');

  // ---------------------------------------------------------------------------
  // Badge definitions (8) - workout_session_repository_impl.dart
  // ---------------------------------------------------------------------------
  out.writeln('''
-- -----------------------------------------------------------------------------
-- 9. badge_defs (8 global badges)
--    Extracted from WorkoutSessionRepositoryImpl._badgeDefinitions.
--    Description is composed from the badge metric + target (not stored in the
--    app); level is unused locally and defaults to 1.
-- -----------------------------------------------------------------------------
insert into public.badge_defs (badge_type, badge_name, icon, description, level, target, sort_order)
values
  ('first_workout', 'First Step', 'direction_run', 'Complete your very first workout.', 1, 1, 1),
  ('workouts_5', 'Consistent', 'repeat', 'Complete 5 workouts.', 1, 5, 2),
  ('workouts_15', 'Dedicated', 'stars', 'Complete 15 workouts.', 1, 15, 3),
  ('workouts_50', 'Iron Warrior', 'military_tech', 'Complete 50 workouts.', 1, 50, 4),
  ('calories_1000', 'Calorie Burner', 'local_fire_department', 'Burn 1000 kcal through workouts.', 1, 1000, 5),
  ('calories_5000', 'Calorie Crusher', 'whatshot', 'Burn 5000 kcal through workouts.', 1, 5000, 6),
  ('streak_7', 'Week Warrior', 'calendar_month', 'Maintain a 7-day workout streak.', 1, 7, 7),
  ('streak_30', 'Month Master', 'workspace_premium', 'Maintain a 30-day workout streak.', 1, 30, 8)
on conflict (badge_type) do nothing;
''');

  // ---------------------------------------------------------------------------
  // Version cursors so clients pull the freshly published catalogs.
  // challenge_defs is intentionally not bumped (no seed data exists today).
  // ---------------------------------------------------------------------------
  out.writeln('''
-- -----------------------------------------------------------------------------
-- 10. Master version cursors
-- -----------------------------------------------------------------------------
select public.bump_master_data_version('meal_categories');
select public.bump_master_data_version('goal_templates');
select public.bump_master_data_version('workout_categories');
select public.bump_master_data_version('exercises');
select public.bump_master_data_version('foods');
select public.bump_master_data_version('workout_templates');
select public.bump_master_data_version('achievement_defs');
select public.bump_master_data_version('badge_defs');
''');

  final File outFile = File('supabase/migrations/002_master_seed.sql');
  outFile.writeAsStringSync(out.toString());
  stdout.writeln(
    'Wrote ${outFile.path} '
    '(${kSeedFoods.length} foods, ${kSeedExercises.length} exercises, '
    '${kSeedWorkouts.length} workouts, $missingExercises unresolved links)',
  );
}

/// SQL string literal; NULL for null values, single quotes doubled, embedded
/// newlines kept literally (valid in PostgreSQL standard string literals).
String s(String? value) {
  if (value == null) return 'NULL';
  return "'${value.replaceAll("'", "''")}'";
}

/// SQL numeric literal from a double (Dart prints e.g. 205.0, valid SQL).
String n(double value) => value.toString();

/// SQL integer literal.
String i(int value) => value.toString();

/// Removes the trailing comma of the last values tuple.
void _trimLastComma(StringBuffer out) {
  final String text = out.toString();
  final int idx = text.lastIndexOf(',');
  if (idx >= 0) {
    out.clear();
    out.write(text.substring(0, idx));
  }
}

class _Category {
  const _Category(this.name, this.slug, this.description, this.icon,
      this.color, this.sortOrder);
  final String name;
  final String slug;
  final String description;
  final String icon;
  final int color;
  final int sortOrder;
}

/// The 21 workout categories as seeded in app_database.dart (v2 + v4).
const List<_Category> _categoryCatalog = <_Category>[
  _Category('Home Workout', 'home_workout',
      'Work out at home with minimal equipment', 'home', 4279148398, 1),
  _Category('Gym Workout', 'gym_workout',
      'Use gym equipment for full training sessions', 'gym', 4285357008, 2),
  _Category('Cardio', 'cardio', 'Get your heart pumping and burn calories',
      'cardio', 4293870660, 3),
  _Category('Yoga', 'yoga',
      'Improve flexibility, balance and mindfulness', 'yoga', 4287323382, 4),
  _Category('Strength', 'strength',
      'Build strength with resistance training', 'strength', 4294538006, 5),
  _Category('HIIT', 'hiit',
      'High intensity interval training for quick results', 'hiit', 4294937088, 6),
  _Category('Stretching', 'stretching',
      'Improve mobility and recover faster', 'stretching', 4279548070, 7),
  _Category('Full Body', 'full_body',
      'Train every major muscle group in one session', 'full_body', 4279148398, 8),
  _Category('Upper Body', 'upper_body',
      'Focus on arms, chest, back and shoulders', 'upper_body', 4282090230, 9),
  _Category('Lower Body', 'lower_body',
      'Build strong legs, glutes and core', 'lower_body', 4294286859, 10),
  _Category('Chest', 'chest', 'Build a stronger, bigger chest', 'chest',
      4293870660, 11),
  _Category('Back', 'back', 'Strengthen your back and posture', 'back',
      4284704497, 12),
  _Category('Shoulder', 'shoulder', 'Sculpt strong, defined shoulders',
      'shoulder', 4282090230, 13),
  _Category('Arms', 'arms', 'Biceps, triceps and forearm strength', 'arms',
      4294538006, 14),
  _Category('Legs', 'legs', 'Powerful legs with squats and lunges', 'legs',
      4287323382, 15),
  _Category('Core', 'core', 'Strengthen your abs and core stability', 'core',
      4293675161, 16),
  _Category('Fat Loss', 'fat_loss',
      'Burn fat with calorie-torching sessions', 'fat_loss', 4294286859, 17),
  _Category('Muscle Gain', 'muscle_gain',
      'Hypertrophy training to build muscle', 'muscle_gain', 4280468830, 18),
  _Category('Beginner', 'beginner', 'Easy, beginner-friendly workouts',
      'beginner', 4279548070, 19),
  _Category('Intermediate', 'intermediate',
      'Moderate workouts for steady progress', 'intermediate', 4282090230, 20),
  _Category('Advanced', 'advanced',
      'Challenging workouts for experienced athletes', 'advanced', 4287323382, 21),
];
