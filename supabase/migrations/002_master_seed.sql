-- =============================================================================
-- NexFit - Master/Reference Data Seed
-- =============================================================================
-- Migration : 002_master_seed.sql
-- Project   : NexFit (Flutter, offline-first, two-way sync)
-- Phase     : 03 - seed data for the global catalogs
--
-- Source of truth : tool/generate_master_seed.dart reads the app seed data
--                   and regenerates this file. Do not hand-edit the data rows.
--
-- Idempotency     : every INSERT uses ON CONFLICT DO NOTHING against the
--                   unique indexes defined in migration 001 (and the two
--                   template constraints added below), so re-running this
--                   migration is a no-op for existing rows.
--
-- Versioning      : master catalogs are bulk-synced by the mobile client via
--                   public.master_data_versions. The final SELECT statements
--                   bump each catalog cursor so clients pull the new rows.
--
-- Rows            : 212 foods, 83 exercises,
--                   26 workout templates, 147 template links,
--                   21 workout categories, 6 meal categories, 4 goal templates,
--                   7 achievements, 8 badges.
-- =============================================================================
-- 0. Complementary unique constraints for idempotent template seeding
create unique index if not exists uq_workout_templates_name
    on public.workout_templates (name);
create unique index if not exists uq_workout_template_exercises_pair
    on public.workout_template_exercises (template_id, exercise_id);

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

-- -----------------------------------------------------------------------------
-- 4. exercises (83 global exercises, user_id IS NULL)
-- -----------------------------------------------------------------------------
insert into public.exercises (
    name, scientific_name, description, instructions, body_part, secondary_muscle,
    equipment, difficulty, category, calories_per_minute, estimated_calories,
    duration_seconds, sets, reps, rest_seconds, tips, common_mistakes,
    safety_instructions
)
values

  ('Push-Ups', 'Press-up', 'A classic bodyweight pressing exercise for the chest, shoulders and triceps.', 'Start in a high plank with hands slightly wider than shoulder width.
Lower your chest towards the floor while keeping your body in a straight line.
Press back up until your arms are fully extended.
Keep your core braced throughout the movement.', 'Chest', 'Triceps, Anterior Deltoids, Core', 'None', 'beginner', 'chest', 7.0, 11, 30, 3, 12, 30, 'Keep your neck neutral by looking at a spot on the floor.
Brace your abs and squeeze your glutes to keep the body rigid.', 'Letting the hips sag or pike up.
Flaring the elbows out to 90 degrees.
Doing half reps with a short range of motion.', 'If you feel wrist pain, use push-up handles or fists.
Lower to a modified (knee) position if your form breaks.'),
  ('Incline Push-Ups', NULL, 'An easier push-up variation performed with hands on an elevated surface.', 'Place your hands on a bench, chair or wall at shoulder width.
Walk your feet back until your body forms a straight line.
Lower your chest towards the surface and press back up.
The higher the surface, the easier the movement.', 'Chest', 'Triceps, Anterior Deltoids', 'None', 'beginner', 'chest', 6.0, 9, 30, 3, 12, 30, 'Keep your body straight from head to heels.
Lower until your chest nearly touches the surface.', 'Bending at the hips instead of keeping a plank line.
Using too high a surface so the range becomes trivial.', 'Check that the bench or chair is stable before placing your hands.'),
  ('Diamond Push-Ups', NULL, 'A narrow-grip push-up that adds extra emphasis to the triceps and inner chest.', 'Place your hands close together under your chest, forming a diamond with your thumbs and index fingers.
Keep your elbows tucked as you lower your chest towards your hands.
Press back up explosively until your arms are straight.', 'Chest', 'Triceps, Inner Chest', 'None', 'intermediate', 'chest', 8.0, 12, 30, 3, 10, 30, 'Keep your elbows close to your ribcage throughout.
Move slowly through the lowering phase.', 'Letting the hips sag.
Flaring elbows away from the body.', 'Stop if you feel sharp wrist or elbow pain.
Scale to incline or knee diamond push-ups when needed.'),
  ('Wide Push-Ups', NULL, 'A wider hand placement that emphasizes the outer chest muscles.', 'Start in a plank with hands wider than shoulder width.
Lower your chest slowly while keeping elbows flared to about 45 degrees.
Drive back up to the starting position.', 'Chest', 'Anterior Deltoids, Triceps', 'None', 'intermediate', 'chest', 7.0, 11, 30, 3, 12, 30, 'Keep a slight bend in the elbows at the top instead of locking out.', 'Placing the hands so wide that the wrists strain.
Letting the chest fall to the floor without control.', 'Avoid full elbow flare to protect the shoulder joint.'),
  ('Decline Push-Ups', NULL, 'Feet elevated push-ups that shift the load to the upper chest and shoulders.', 'Place your feet on a bench or chair and hands on the floor.
Lower your chest towards the floor with control.
Press back up strongly to complete the rep.', 'Chest', 'Upper Chest, Shoulders', 'None', 'advanced', 'chest', 8.0, 12, 30, 3, 10, 30, 'Keep your hips level and avoid arching your back.', 'Sagging the hips because the feet are elevated.
Bouncing at the bottom of the rep.', 'Secure the bench before starting.
Use a lower elevation if you cannot keep your hips square.'),
  ('Chest Dips', NULL, 'A demanding pressing movement performed on parallel bars or sturdy chairs.', 'Grip the bars and lift yourself with arms straight.
Lean slightly forward and lower your body until your shoulders are below your elbows.
Press back up to the starting position without locking out harshly.', 'Chest', 'Triceps, Shoulders', 'None', 'advanced', 'chest', 9.0, 14, 30, 3, 10, 45, 'Lean forward to keep the emphasis on the chest.
Lower slowly and under control.', 'Going too deep and straining the shoulders.
Using momentum instead of muscle.', 'Ensure chairs or bars are stable before loading them.
Stop if you feel shoulder pain.'),
  ('Dumbbell Bench Press', 'Dumbbell Chest Press', 'A dumbbell pressing movement that builds chest size and strength.', 'Lie on a bench holding a dumbbell in each hand at chest level.
Press the dumbbells up until your arms are extended.
Lower them slowly back to chest level with control.', 'Chest', 'Triceps, Anterior Deltoids', 'Dumbbell', 'intermediate', 'chest', 8.0, 16, 30, 4, 10, 45, 'Keep your feet planted and your back slightly arched.
Lower to a comfortable stretch without flaring elbows too wide.', 'Bouncing the weights off the chest.
Raising the shoulders off the bench.', 'Use a spotter or safety arms for heavy sets.
Control the weights when lowering to avoid shoulder injury.'),
  ('Dumbbell Fly', 'Dumbbell Chest Fly', 'An isolation movement that stretches and strengthens the chest.', 'Lie on a bench with dumbbells extended above your chest, palms facing each other.
Open your arms in a wide arc until you feel a chest stretch.
Squeeze your chest to bring the dumbbells back together.', 'Chest', 'Biceps, Anterior Deltoids', 'Dumbbell', 'intermediate', 'chest', 7.0, 11, 30, 3, 12, 45, 'Keep a soft bend in the elbows throughout.
Move slowly and feel the stretch in your chest.', 'Dropping the arms too deep and straining the shoulders.
Using too much weight and turning it into a press.', 'Start with light weight until you master the form.'),
  ('Dumbbell Pullover', 'Straight-arm Pullover', 'A single-dumbbell movement that stretches the chest while engaging the lats.', 'Lie across a bench holding one dumbbell with both hands above your chest.
Lower the dumbbell back behind your head with straight arms.
Pull it back over your chest to complete the rep.', 'Chest', 'Lats, Triceps, Core', 'Dumbbell', 'intermediate', 'chest', 8.0, 12, 30, 3, 10, 45, 'Keep your hips low and your ribs from flaring.
Control the lowering phase deeply.', 'Bending the elbows too much.
Arching the lower back excessively.', 'Use a spotter or a secure bench.
Stop if you feel a sharp pull in the shoulder.'),
  ('Pull-Ups', 'Overhand-grip Pull-up', 'The king of upper-body pulling exercises for a wide, strong back.', 'Hang from a bar with an overhand grip slightly wider than shoulders.
Pull your chest towards the bar by driving your elbows down.
Lower yourself with control until your arms are fully extended.', 'Back', 'Biceps, Forearms, Core', 'Pull-up bar', 'advanced', 'back', 9.0, 18, 30, 4, 8, 45, 'Pull with your back, not just your arms.
Keep your shoulders down and away from your ears.', 'Swinging the legs to generate momentum.
Half reps without a full hang at the bottom.', 'Warm up your shoulders before attempting.
Use an assisted band or machine if you cannot complete one rep.'),
  ('Prone Y Raise', 'Prone Y Exercise', 'A low-impact exercise that strengthens the upper back and improves posture.', 'Lie face down with arms extended overhead forming a Y shape.
Lift your arms and chest off the floor, squeezing your shoulder blades.
Hold briefly, then lower back down with control.', 'Back', 'Rear Deltoids, Rotator Cuff', 'None', 'beginner', 'back', 6.0, 9, 30, 3, 12, 20, 'Squeeze the shoulder blades together at the top.
Keep the neck neutral by looking down.', 'Shrugging the shoulders up to the ears.
Lifting the legs instead of the chest.', 'Move slowly and avoid jerky lifts.'),
  ('Bent-Over Dumbbell Row', 'Two-arm Bent-over Row', 'A compound pulling movement that builds back width and thickness.', 'Hinge at the hips with a flat back, holding a dumbbell in each hand.
Row the dumbbells towards your hips, squeezing your shoulder blades.
Lower them back down under control.', 'Back', 'Biceps, Rear Deltoids, Core', 'Dumbbell', 'intermediate', 'back', 8.0, 16, 30, 4, 10, 45, 'Keep your back flat and hinge from the hips.
Pull the elbows towards your back pockets.', 'Rounding the lower back.
Using the whole body to swing the weights.', 'Start light to protect the lower back.
Keep your neck in line with your spine.'),
  ('One-Arm Dumbbell Row', 'Single-arm Bent-over Row', 'A unilateral row that corrects imbalances and builds back strength.', 'Place one knee and hand on a bench, the other foot on the floor.
Hold a dumbbell with a neutral grip and row it to your hip.
Lower it fully and repeat for the prescribed reps.', 'Back', 'Biceps, Core, Lats', 'Dumbbell', 'intermediate', 'back', 8.0, 12, 30, 3, 10, 45, 'Keep your torso square, not rotating at the top.
Pull the elbow straight back towards the ceiling.', 'Rotating the torso to lift the weight.
Rowing with the shoulder instead of the back.', 'Ensure the bench is stable.
Use a controlled tempo to avoid straining the shoulder.'),
  ('Renegade Row', 'Plank Row', 'A plank position row that challenges the back and core together.', 'Start in a high plank gripping two dumbbells.
Row one dumbbell towards your hip while keeping your hips square.
Lower it and repeat on the other side without losing plank position.', 'Back', 'Core, Triceps, Shoulders', 'Dumbbell', 'advanced', 'back', 9.0, 14, 30, 3, 8, 45, 'Squeeze the glutes to keep the hips from rotating.
Row with control, not speed.', 'Letting the hips twist while rowing.
Placing the weights too far apart.', 'Start with light dumbbells.
If your core tires, take a short break between sides.'),
  ('Reverse Fly', 'Rear-delt Raise', 'An isolation exercise for the rear deltoids and upper back.', 'Hinge forward with a flat back, holding dumbbells at your sides.
Raise the dumbbells out to the sides until they reach shoulder height.
Lower them back down with control.', 'Back', 'Rear Deltoids, Rhomboids', 'Dumbbell', 'intermediate', 'back', 7.0, 11, 30, 3, 12, 30, 'Squeeze the shoulder blades as you raise.
Keep a slight bend in the elbows.', 'Shrugging the shoulders.
Using momentum to swing the weights up.', 'Use light weight to avoid impingement.'),
  ('Superman', 'Prone Supermans', 'A low-impact movement that strengthens the entire posterior chain.', 'Lie face down with arms extended forward.
Lift your arms, chest and legs off the floor together.
Hold briefly, then lower back down.', 'Back', 'Glutes, Hamstrings', 'None', 'beginner', 'back', 4.0, 4, 20, 3, 10, 20, 'Keep the neck neutral and look at the floor.
Squeeze the glutes at the top.', 'Snapping the head back.
Lifting with a jerky motion.', 'Avoid this if you have lower back issues; move slowly.'),
  ('Dumbbell Shoulder Press', 'Seated DB Overhead Press', 'A primary overhead pressing movement for shoulder size and strength.', 'Hold dumbbells at shoulder height with palms facing forward.
Press them overhead until your arms are fully extended.
Lower them back to shoulder height with control.', 'Shoulders', 'Triceps, Upper Traps', 'Dumbbell', 'intermediate', 'shoulder', 8.0, 16, 30, 4, 10, 45, 'Brace your core to avoid arching your lower back.
Press in a slightly curved path rather than straight up.', 'Arching the back excessively.
Locking out the elbows harshly.', 'Use a bench with back support for heavy sets.
Stop if you feel sharp shoulder pain.'),
  ('Lateral Raises', 'Side Lateral Raise', 'An isolation exercise that builds the middle deltoid for wider shoulders.', 'Stand holding light dumbbells at your sides.
Raise the dumbbells out to the sides until arm height.
Lower them slowly back to your sides.', 'Shoulders', 'Traps, Upper Back', 'Dumbbell', 'beginner', 'shoulder', 6.0, 9, 30, 3, 15, 30, 'Lead with the elbows, not the hands.
Keep a soft bend in the elbows.', 'Swinging the body to lift the weight.
Raising above shoulder height and straining the neck.', 'Use light dumbbells to protect the shoulder joint.'),
  ('Front Raises', 'Anterior Raise', 'An isolation exercise targeting the front deltoid.', 'Stand holding dumbbells in front of your thighs.
Raise one arm forward to shoulder height.
Lower it and alternate arms.', 'Shoulders', 'Upper Chest', 'Dumbbell', 'beginner', 'shoulder', 6.0, 9, 30, 3, 12, 30, 'Keep the movement smooth and avoid leaning back.', 'Using momentum from the hips.
Raising the arm too high and shrugging.', 'Keep the weight light to protect the front shoulder.'),
  ('Pike Push-Ups', 'Bodyweight Overhead Press', 'A bodyweight overhead press that builds shoulder strength.', 'Start in a pike position with hips high and head near the floor.
Bend your elbows to lower the top of your head towards the floor.
Press back up to the pike position.', 'Shoulders', 'Triceps, Upper Chest', 'None', 'advanced', 'shoulder', 8.0, 12, 30, 3, 10, 45, 'Keep the hips high throughout.
Lower with control until your head is close to the floor.', 'Rounding the back and collapsing the hips.
Letting the head drop suddenly.', 'Place a mat under your head.
Stop if you feel wrist or shoulder pain.'),
  ('Arnold Press', 'Rotating Overhead Press', 'A rotating shoulder press that hits all three deltoid heads.', 'Hold dumbbells at shoulder height with palms facing you.
Press overhead while rotating your palms to face forward.
Reverse the motion as you lower the dumbbells.', 'Shoulders', 'Triceps, Traps', 'Dumbbell', 'intermediate', 'shoulder', 8.0, 12, 30, 3, 10, 45, 'Rotate smoothly as you press.
Keep the core tight throughout.', 'Rushing the rotation.
Arching the lower back.', 'Use a moderate weight to maintain control through the rotation.'),
  ('Bicep Curls', 'Dumbbell Bicep Curl', 'The classic isolation movement for building the biceps.', 'Stand holding dumbbells with palms facing forward.
Curl the dumbbells up towards your shoulders.
Lower them slowly without swinging your body.', 'Biceps', 'Forearms', 'Dumbbell', 'beginner', 'biceps', 6.0, 9, 30, 3, 12, 30, 'Pin your elbows to your sides.
Squeeze the biceps at the top of the curl.', 'Swinging the weight with body momentum.
Moving the elbows forward at the top.', 'Use a weight you can control through the full range.'),
  ('Hammer Curls', 'Neutral-grip Curl', 'A neutral-grip curl that also builds the brachialis and forearms.', 'Hold dumbbells with a neutral grip, palms facing each other.
Curl the weights up while keeping your wrists neutral.
Lower them back down under control.', 'Biceps', 'Brachialis, Forearms', 'Dumbbell', 'intermediate', 'biceps', 6.0, 9, 30, 3, 12, 30, 'Keep the wrists straight throughout.
Control the negative phase slowly.', 'Twisting the wrists as you curl.
Using the shoulders to help lift.', 'Keep the elbows at your sides to protect the shoulders.'),
  ('Concentration Curls', 'Isolated Bicep Curl', 'A seated curl that isolates the biceps for a powerful contraction.', 'Sit on a bench with your legs apart, holding a dumbbell in one hand.
Rest your elbow against your inner thigh.
Curl the weight up towards your shoulder and lower slowly.', 'Biceps', 'Forearms', 'Dumbbell', 'beginner', 'biceps', 6.0, 9, 30, 3, 12, 30, 'Squeeze the biceps hard at the top.
Keep the upper arm fully stationary.', 'Rocking the torso to lift the weight.
Dropping the shoulder.', 'Use a light weight for strict form.'),
  ('Tricep Dips', 'Bench Dips', 'A bodyweight movement that builds the triceps using a bench or chair.', 'Sit on the edge of a bench with hands next to your hips.
Slide off and lower your body by bending your elbows to 90 degrees.
Press back up to full arm extension.', 'Triceps', 'Chest, Shoulders', 'None', 'beginner', 'triceps', 7.0, 11, 30, 3, 12, 30, 'Keep your back close to the bench.
Lower until your elbows reach about 90 degrees.', 'Dropping too deep and straining the shoulders.
Walking the feet too far away and turning it into a push-up.', 'Ensure the bench is stable.
Stop if you feel shoulder pain.'),
  ('Overhead Tricep Extension', 'Standing DB Triceps Extension', 'An isolation exercise that lengthens and builds the triceps.', 'Hold a dumbbell overhead with both hands.
Lower the weight behind your head by bending your elbows.
Extend your arms back overhead to complete the rep.', 'Triceps', 'Long Head of Triceps, Forearms', 'Dumbbell', 'intermediate', 'triceps', 7.0, 11, 30, 3, 12, 30, 'Keep your elbows pointing forward and close to your head.
Lower until you feel a stretch in the triceps.', 'Letting the elbows flare outwards.
Arching the back to support the weight.', 'Keep the core braced.
Use a weight you can lower with control.'),
  ('Tricep Kickbacks', 'Dumbbell Kickback', 'An isolation movement that finishes the triceps with a strong squeeze.', 'Hinge forward with a flat back, upper arms parallel to the floor.
Extend your forearms back until the arms are straight.
Pause and squeeze, then lower back with control.', 'Triceps', 'Forearms, Rear Deltoids', 'Dumbbell', 'beginner', 'triceps', 6.0, 9, 30, 3, 12, 30, 'Keep the upper arms completely still.
Squeeze the triceps at full extension.', 'Moving the whole arm instead of just the forearm.
Using too heavy a weight and swinging.', 'Use a light dumbbell for strict form.'),
  ('Skull Crushers', 'Lying Triceps Extension', 'A lying triceps extension that isolates the long head of the triceps.', 'Lie on a bench holding dumbbells above your chest.
Lower them towards your head by bending only your elbows.
Extend your arms back to the starting position.', 'Triceps', 'Forearms', 'Dumbbell', 'advanced', 'triceps', 7.0, 11, 30, 3, 10, 45, 'Keep the elbows pointed up and stationary.
Lower slowly towards your ears.', 'Flaring the elbows outward.
Letting the weight drop quickly towards the head.', 'Use a spotter for heavy sets.
Stop if you feel elbow pain.'),
  ('Squats', 'Bodyweight Squat', 'A fundamental lower-body movement that builds legs, glutes and core.', 'Stand with feet shoulder width apart.
Lower your hips back and down until your thighs are parallel to the floor.
Drive through your heels to stand back up.', 'Legs', 'Glutes, Core, Hamstrings', 'None', 'beginner', 'legs', 8.0, 12, 30, 3, 15, 30, 'Push your knees out in line with your toes.
Keep your chest up and back neutral.', 'Letting the knees cave inward.
Raising the heels off the floor.
Rounding the lower back at the bottom.', 'Keep your knees tracking over your toes.
Stop if you feel sharp knee pain.'),
  ('Chair Squats', 'Assisted Squat', 'A squat performed to a chair that teaches safe lowering mechanics.', 'Stand in front of a chair with feet shoulder width apart.
Sit back until your hips touch the chair, without collapsing onto it.
Drive back up to standing.', 'Legs', 'Glutes, Core', 'Chair', 'beginner', 'legs', 6.0, 9, 30, 3, 12, 30, 'Reach your hips back as if sitting down.
Touch the chair lightly, then stand.', 'Dropping onto the chair with momentum.
Leaning the torso too far forward.', 'Use a sturdy, non-slip chair.'),
  ('Jump Squats', 'Squat Jump', 'An explosive squat variation that builds power and burns calories.', 'Perform a squat and explode upward into a jump.
Land softly with bent knees.
Immediately sink into the next squat.', 'Legs', 'Calves, Glutes, Core', 'None', 'intermediate', 'legs', 10.0, 15, 30, 3, 12, 30, 'Land softly on the balls of your feet.
Keep the core tight on the landing.', 'Landing on locked knees.
Leaning too far forward on the jump.', 'Avoid on hard surfaces or with knee problems.
Land softly and absorb the impact with bent knees.'),
  ('Jump Lunges', 'Alternating Jump Lunge', 'An explosive lunge that builds power, balance and cardiovascular endurance.', 'Step into a lunge position with both knees bent to 90 degrees.
Explode upward and switch legs mid-air.
Land softly into the opposite lunge.', 'Legs', 'Glutes, Calves, Core', 'None', 'advanced', 'legs', 11.0, 17, 30, 3, 10, 45, 'Keep your torso upright.
Land with the knees tracking over the toes.', 'Landing heavily on a straight leg.
Letting the front knee drift inward.', 'Master a static lunge first.
Stop if you feel knee pain.'),
  ('Lunges', 'Forward Lunge', 'A unilateral leg exercise that improves balance and strength.', 'Step forward with one leg and lower your hips until both knees are bent 90 degrees.
Push off the front foot to return to standing.
Alternate legs for each rep.', 'Legs', 'Glutes, Hamstrings, Core', 'None', 'beginner', 'legs', 8.0, 12, 30, 3, 12, 30, 'Keep your front knee behind your toes.
Keep your torso tall and shoulders back.', 'Letting the front knee cave inward.
Taking steps that are too short.', 'Take a long enough step to avoid knee strain.
Use a wall for balance if needed.'),
  ('Bulgarian Split Squats', 'Rear-foot Elevated Split Squat', 'A demanding single-leg squat that challenges the entire lower body.', 'Place one foot behind you on a bench or chair.
Lower your hips straight down until your front thigh is parallel.
Drive up through your front heel to stand.', 'Legs', 'Glutes, Core', 'None', 'advanced', 'legs', 9.0, 14, 30, 3, 10, 45, 'Keep most of the weight on the front leg.
Maintain a tall chest.', 'Pushing through the back leg.
Letting the front knee drift inward.', 'Secure the bench before starting.
Start bodyweight-only until balance improves.'),
  ('Wall Sit', 'Wall Squat Hold', 'An isometric hold that builds endurance in the quadriceps.', 'Slide your back down a wall until your thighs are parallel to the floor.
Hold the position with knees at 90 degrees.
Breathe steadily and hold for the full duration.', 'Legs', 'Glutes, Calves', 'None', 'beginner', 'legs', 5.0, 11, 45, 3, 0, 20, 'Press your entire back into the wall.
Keep the knees over the ankles.', 'Sliding up when it gets hard.
Holding the breath.', 'Step out carefully if your legs shake or give out.'),
  ('Romanian Deadlift', 'Stiff-leg Deadlift', 'A hip-hinge movement that targets the hamstrings and glutes.', 'Hold dumbbells in front of your thighs with a slight knee bend.
Hinge at the hips, pushing them back as you lower the weights.
Return to standing by driving your hips forward.', 'Legs', 'Hamstrings, Glutes, Lower Back', 'Dumbbell', 'intermediate', 'legs', 8.0, 12, 30, 3, 12, 45, 'Keep a flat back throughout.
Push the hips back, not just bend down.', 'Rounding the lower back.
Bending the knees too much into a squat.', 'Start with light weight.
Keep the bar or dumbbells close to your legs.'),
  ('Step-Ups', 'Box Step-up', 'A functional leg exercise using a bench or step.', 'Place one foot fully on a sturdy bench or step.
Drive through that foot to lift your body up.
Lower yourself back down and repeat on the other leg.', 'Legs', 'Glutes, Hamstrings', 'None', 'intermediate', 'legs', 8.0, 12, 30, 3, 12, 30, 'Push through the whole foot, especially the heel.
Keep the knee tracking over the toes.', 'Pushing off the bottom leg.
Using a step that is too high.', 'Use a stable bench.
Step down with control to protect the knees.'),
  ('Sumo Squats', 'Wide-stance Squat', 'A wide-stance squat that emphasizes the inner thighs and glutes.', 'Stand with feet wider than shoulder width and toes turned out.
Lower your hips down between your legs.
Press back up through your heels.', 'Legs', 'Adductors, Glutes', 'None', 'intermediate', 'legs', 8.0, 12, 30, 3, 12, 30, 'Keep the knees tracking over the toes.
Sit down into the space between your legs.', 'Letting the knees collapse inward.
Leaning the torso too far forward.', 'Keep a controlled tempo to protect the knees.'),
  ('Calf Raises', 'Standing Calf Raise', 'A simple movement that strengthens and shapes the calves.', 'Stand tall with feet shoulder width apart.
Rise onto the balls of your feet as high as possible.
Lower your heels back down with control.', 'Calves', 'Soleus, Ankles', 'None', 'beginner', 'legs', 5.0, 10, 30, 4, 20, 20, 'Pause at the top of the raise.
Lower slowly for a full stretch.', 'Bouncing at the bottom.
Doing half reps.', 'Hold a wall for balance if needed.'),
  ('Glute Bridges', 'Supine Hip Bridge', 'A hip extension exercise that activates and builds the glutes.', 'Lie on your back with knees bent and feet flat on the floor.
Drive through your heels to lift your hips toward the ceiling.
Squeeze your glutes at the top, then lower back down.', 'Glutes', 'Hamstrings, Core', 'None', 'beginner', 'glutes', 5.0, 8, 30, 3, 15, 20, 'Squeeze the glutes hard at the top.
Keep the ribcage down and avoid over-arching.', 'Pushing through the toes instead of the heels.
Hyperextending the lower back at the top.', 'Keep the movement controlled to protect the lower back.'),
  ('Glute Kickbacks', 'Quadruped Hip Extension', 'A quadruped movement that isolates the glutes with a full contraction.', 'Start on all fours with a neutral spine.
Drive one heel up and back toward the ceiling, squeezing the glute.
Lower back down and switch sides.', 'Glutes', 'Hamstrings', 'None', 'beginner', 'glutes', 5.0, 8, 30, 3, 12, 20, 'Keep the hips level, not rotating.
Squeeze at the top of the kickback.', 'Arching the lower back to kick higher.
Twisting the hips.', 'Keep the core braced throughout.'),
  ('Fire Hydrants', 'Quadruped Hip Abduction', 'A hip-abduction move that activates the glute medius.', 'Start on all fours with a neutral spine.
Lift one bent knee out to the side as high as comfortable.
Lower back down and repeat on the other side.', 'Glutes', 'Hip Abductors, Core', 'None', 'beginner', 'glutes', 5.0, 8, 30, 3, 12, 20, 'Keep the hips square and level.
Move from the hip, not the spine.', 'Rotating the torso to gain height.
Raising the leg too high and tilting the hips.', 'Stay within a pain-free range of motion.'),
  ('Plank', 'Front Plank', 'An isometric core exercise that builds full-body stability.', 'Start on your forearms and toes with your body in a straight line.
Keep your core braced and avoid letting your hips sag.
Hold the position while breathing steadily.', 'Core', 'Shoulders, Glutes, Back', 'None', 'beginner', 'core', 5.0, 11, 45, 3, 0, 20, 'Squeeze the glutes to keep the hips up.
Breathe slowly instead of holding your breath.', 'Letting the hips sag or pike up.
Looking up and straining the neck.', 'Drop to your knees if you cannot keep a straight line.'),
  ('Side Plank', 'Lateral Plank', 'An isometric hold that strengthens the obliques and stabilizers.', 'Lie on your side supported by one forearm.
Lift your hips so your body forms a straight line.
Hold while keeping your core engaged.', 'Core', 'Obliques, Glutes, Shoulders', 'None', 'intermediate', 'core', 5.0, 8, 30, 3, 0, 20, 'Stack your feet or stagger them for balance.
Push the floor away with your forearm.', 'Letting the hips drop.
Rolling the shoulders forward.', 'Shorten the hold if your form starts to break.'),
  ('Crunches', 'Abdominal Crunch', 'A controlled movement that targets the upper abdominal muscles.', 'Lie on your back with knees bent and hands behind your head.
Curl your shoulders off the floor using your abs.
Lower back down without fully relaxing the core.', 'Core', 'Obliques', 'None', 'beginner', 'abs', 6.0, 9, 30, 3, 20, 20, 'Exhale as you crunch up.
Keep your chin off your chest.', 'Pulling on the neck with your hands.
Using momentum to swing up.', 'Keep a small gap between your chin and chest.
Stop if you feel neck strain.'),
  ('Bicycle Crunches', 'Bicycle Maneuver', 'A dynamic core exercise that hits the entire abdominal wall.', 'Lie on your back with hands behind your head.
Bring one knee in while twisting to touch it with the opposite elbow.
Alternate sides in a smooth pedaling motion.', 'Core', 'Obliques, Hip Flexors', 'None', 'intermediate', 'abs', 8.0, 12, 30, 3, 20, 20, 'Move slowly with control.
Keep the lower back pressed into the floor.', 'Pulling on the neck.
Moving too fast and losing form.', 'Support your head lightly with your fingertips.'),
  ('Leg Raises', 'Supine Leg Raise', 'An exercise that targets the lower abs and hip flexors.', 'Lie flat with legs straight and hands under your hips.
Raise your legs to 90 degrees keeping them straight.
Lower them slowly without letting your lower back lift.', 'Core', 'Hip Flexors, Lower Abs', 'None', 'intermediate', 'abs', 7.0, 11, 30, 3, 15, 20, 'Press the lower back into the floor.
Lower the legs slowly for control.', 'Letting the lower back arch.
Swinging the legs.', 'Bend the knees if you feel lower back strain.'),
  ('Russian Twists', 'Seated Twist', 'A rotational core movement that builds oblique strength.', 'Sit with knees bent, lean back slightly and lift your feet.
Rotate your torso to touch the floor beside one hip.
Alternate sides while keeping your chest tall.', 'Core', 'Obliques, Hip Flexors', 'None', 'intermediate', 'core', 7.0, 11, 30, 3, 20, 20, 'Rotate from the torso, not just the arms.
Keep the chest lifted.', 'Rounding the back.
Holding the breath.', 'Keep the feet down if you struggle to balance.'),
  ('Mountain Climbers', 'Running Plank', 'A full-body cardio move that strongly engages the core.', 'Start in a high plank position.
Drive one knee towards your chest, then quickly switch legs.
Keep your hips low and your pace steady.', 'Core', 'Shoulders, Hip Flexors, Cardio', 'None', 'intermediate', 'core', 9.0, 18, 40, 3, 0, 20, 'Keep the hips low and level.
Drive the knees to the chest, not the floor.', 'Letting the hips rise up.
Sliding the feet instead of driving the knees.', 'Slow the pace if your form breaks.'),
  ('Flutter Kicks', 'Flutter Kick', 'A lower-ab exercise performed with alternating leg kicks.', 'Lie on your back with legs extended and hands under your hips.
Lift your heels slightly and flutter your legs up and down.
Keep your lower back pressed into the floor.', 'Core', 'Hip Flexors, Quads', 'None', 'beginner', 'abs', 6.0, 9, 30, 3, 0, 20, 'Keep the kicks small and controlled.
Press the lower back into the floor.', 'Kicking too high and arching the back.
Letting the lower back lift off the floor.', 'Bend the knees if you feel lower back strain.'),
  ('Hollow Body Hold', 'Hollow Rock Hold', 'A demanding isometric hold that builds deep core strength.', 'Lie on your back and lift your shoulders and legs off the floor.
Press your lower back firmly into the ground.
Hold the hollow position while breathing steadily.', 'Core', 'Hip Flexors, Lower Abs', 'None', 'advanced', 'core', 6.0, 9, 30, 3, 0, 20, 'Keep the arms straight by your ears.
Press the lower back down hard.', 'Letting the lower back arch.
Dropping the legs too low.', 'Raise the legs higher if your back arches.'),
  ('V-Ups', 'V-sit Crunch', 'A full-ab movement that raises both arms and legs into a V.', 'Lie flat with arms extended overhead.
Lift your arms and legs together to touch your toes.
Lower back down with control.', 'Core', 'Hip Flexors', 'None', 'intermediate', 'abs', 7.0, 11, 30, 3, 12, 20, 'Exhale as you fold up.
Keep the movement controlled.', 'Using momentum to swing up.
Rounding the back violently.', 'Bend the knees if you feel lower back strain.'),
  ('Heel Touches', 'Side Crunch', 'A light oblique movement that reaches one hand toward each heel.', 'Lie on your back with knees bent and feet flat.
Reach your right hand toward your right heel, crunching the obliques.
Alternate sides in a controlled rhythm.', 'Core', 'Obliques', 'None', 'beginner', 'abs', 5.0, 8, 30, 3, 16, 20, 'Move from the ribs, not the shoulders.
Keep the chin off the chest.', 'Only moving the arms without crunching.
Pulling on the neck.', 'Keep a comfortable neck position.'),
  ('Reverse Crunches', 'Lying Knee-to-chest Crunch', 'A lower-ab crunch that curls the hips toward the ribs.', 'Lie on your back with knees bent and feet off the floor.
Curl your knees toward your chest, lifting the hips.
Lower back down without touching the floor.', 'Core', 'Hip Flexors, Lower Abs', 'None', 'intermediate', 'abs', 6.0, 9, 30, 3, 12, 20, 'Lift the hips at the top of the crunch.
Control the lowering phase.', 'Swinging the legs.
Letting the lower back pop off the floor.', 'Move slowly to protect the lower back.'),
  ('Dead Bug', 'Supine Alternating Extension', 'A low-impact core drill that trains anti-extension and stability.', 'Lie on your back with arms up and knees bent over your hips.
Lower one arm and the opposite leg toward the floor.
Return to the start and switch sides.', 'Core', 'Hip Flexors, Lower Back', 'None', 'beginner', 'core', 4.0, 6, 30, 3, 10, 20, 'Keep the lower back pressed into the floor.
Move slowly and breathe.', 'Arching the lower back as limbs extend.
Rushing the movement.', 'Shorten the range if your back arches.'),
  ('Bird Dog', 'Quadruped Opposite Arm/Leg', 'A balance drill that strengthens the core and posterior chain.', 'Start on all fours with a neutral spine.
Extend one arm forward and the opposite leg back.
Hold, then return and switch sides.', 'Core', 'Glutes, Lower Back', 'None', 'beginner', 'core', 4.0, 6, 30, 3, 10, 20, 'Keep the hips square to the floor.
Reach long without arching the back.', 'Rotating the hips.
Lifting the head.', 'Move slowly and keep the core braced.'),
  ('Plank Jacks', 'Plank Jumping Jack', 'A plank that adds a hopping leg jump for a cardio-core challenge.', 'Start in a high plank position.
Jump your feet apart, then back together.
Keep the hips low and the core tight.', 'Core', 'Shoulders, Glutes', 'None', 'intermediate', 'core', 8.0, 12, 30, 3, 15, 20, 'Keep the hips from bouncing.
Land softly on the balls of your feet.', 'Letting the hips rise or sag.
Hopping too wide.', 'Stop if your wrists or shoulders tire.'),
  ('Jumping Jacks', 'Star Jump', 'A classic full-body cardio exercise that raises the heart rate quickly.', 'Stand with feet together and arms at your sides.
Jump while spreading your legs and raising your arms overhead.
Jump back to the starting position and repeat.', 'Cardio', 'Calves, Shoulders, Core', 'None', 'beginner', 'cardio', 9.0, 18, 40, 3, 0, 20, 'Land softly on the balls of your feet.
Keep a steady, rhythmic pace.', 'Landing on flat, heavy feet.
Flapping the arms without rhythm.', 'Slow down or march in place if you get winded.'),
  ('High Knees', 'Running in Place', 'A running-in-place drill that builds speed and cardio capacity.', 'Jog in place while driving your knees up towards your chest.
Pump your arms in rhythm with your legs.
Keep your pace fast and your core engaged.', 'Cardio', 'Hip Flexors, Core, Calves', 'None', 'intermediate', 'cardio', 10.0, 20, 40, 3, 0, 20, 'Drive the knees to hip height.
Stay tall instead of leaning back.', 'Slouching forward.
Lifting the knees only a few inches.', 'Keep a soft landing to protect the knees.'),
  ('Burpees', 'Squat Thrust Push-up', 'A full-body, high-intensity exercise that combines a squat, push-up and jump.', 'Squat down and place your hands on the floor.
Jump your feet back into a plank and perform a push-up.
Jump your feet forward and explode up into a jump.', 'Cardio', 'Chest, Core, Legs, Shoulders', 'None', 'advanced', 'cardio', 12.0, 24, 40, 3, 0, 30, 'Keep the core tight through the plank.
Breathe rhythmically instead of holding.', 'Skipping the push-up.
Letting the hips sag in the plank.', 'Remove the push-up or jump for an easier version.
Stop if you feel dizzy or lightheaded.'),
  ('Skaters', 'Lateral Lunge Hop', 'A lateral jumping exercise that improves agility and burns calories.', 'Stand on one leg and jump sideways to the other leg.
Land softly, swinging your arms to maintain balance.
Keep the motion continuous from side to side.', 'Cardio', 'Glutes, Quads, Core', 'None', 'intermediate', 'cardio', 9.0, 18, 40, 3, 0, 20, 'Land in a mini-squat to absorb the impact.
Swing the arms for momentum.', 'Landing on a straight leg.
Taking tiny, shuffling steps.', 'Widen your base for balance if needed.
Avoid on slippery surfaces.'),
  ('Butt Kicks', 'Heel-up Run', 'A running drill that kicks the heels toward the glutes.', 'Jog in place bringing your heels up to your glutes.
Keep your knees pointed down and your pace quick.
Pump your arms to keep the rhythm.', 'Cardio', 'Hamstrings, Calves', 'None', 'beginner', 'cardio', 8.0, 16, 40, 3, 0, 20, 'Aim the heels for the glutes each kick.
Stay light on the feet.', 'Lifting the knees instead of the heels.
Leaning too far forward.', 'Keep a soft, quick cadence.'),
  ('Bear Crawls', 'Quadruped Crawl', 'A quadruped movement that builds strength, coordination and cardio.', 'Start on all fours with knees slightly off the floor.
Crawl forward moving opposite hand and foot together.
Keep your hips low and back flat.', 'Cardio', 'Shoulders, Core, Quads', 'None', 'intermediate', 'cardio', 9.0, 14, 30, 3, 0, 20, 'Keep the knees a few inches off the floor.
Take small, controlled steps.', 'Crawling on the knees.
Letting the hips shoot up.', 'Shorten the distance if your shoulders tire.'),
  ('Jump Rope', 'Skipping', 'A high-efficiency cardio drill that improves coordination and stamina.', 'Hold the rope handles with elbows close to your sides.
Swing the rope and jump as it passes under your feet.
Land softly on the balls of your feet and repeat.', 'Cardio', 'Calves, Shoulders, Core', 'Jump Rope', 'intermediate', 'cardio', 12.0, 24, 40, 3, 0, 20, 'Jump just high enough to clear the rope.
Keep a steady rhythm with small wrist rotations.', 'Jumping too high.
Swinging the arms instead of the wrists.', 'Use a rope sized to your height.
Check the floor is clear of obstacles.'),
  ('Child''s Pose', 'Balasana', 'A resting yoga pose that gently stretches the back and hips.', 'Kneel and sit back on your heels.
Fold forward, extending your arms in front of you.
Rest your forehead on the floor and breathe deeply.', 'Stretching', 'Back, Hips, Shoulders', 'None', 'beginner', 'stretching', 3.0, 6, 60, 2, 0, 10, 'Breathe deeply into the lower back.
Widen the knees for a deeper stretch.', 'Lifting the hips off the heels.
Forcing the forehead to the floor.', 'Place a cushion under your knees if needed.'),
  ('Cobra Stretch', 'Bhujangasana', 'A gentle backbend that opens the chest and strengthens the spine.', 'Lie face down with hands under your shoulders.
Press your palms down to lift your chest off the floor.
Keep your hips down and breathe deeply.', 'Stretching', 'Chest, Shoulders, Core', 'None', 'beginner', 'stretching', 3.0, 5, 45, 2, 0, 10, 'Lift through the chest, not the arms.
Keep the elbows slightly bent.', 'Shrugging the shoulders.
Pushing up too far and straining the back.', 'Keep the lift gentle; avoid pain in the lower back.'),
  ('Standing Forward Fold', 'Uttanasana', 'A hamstring and lower-back stretch performed standing.', 'Stand tall with feet hip width apart.
Hinge at the hips and fold forward, letting your head hang.
Bend your knees slightly if needed and breathe deeply.', 'Stretching', 'Hamstrings, Lower Back, Calves', 'None', 'beginner', 'stretching', 3.0, 6, 60, 2, 0, 10, 'Relax the neck and let gravity help.
Bend the knees to protect the lower back.', 'Rounding the back and snapping the knees.
Bouncing in the stretch.', 'Rise slowly to avoid dizziness.'),
  ('Seated Hamstring Stretch', 'Paschimottanasana', 'A seated stretch that targets the hamstrings and lower back.', 'Sit with one leg extended and the other bent to the side.
Reach forward toward your extended foot.
Hold while breathing evenly, then switch sides.', 'Stretching', 'Hamstrings, Lower Back', 'None', 'beginner', 'stretching', 3.0, 5, 45, 2, 0, 10, 'Hinge from the hips, keeping the chest open.
Use a strap around the foot if you cannot reach.', 'Rounding the back to reach further.
Locking the knee hard.', 'Keep a soft bend in the knee.'),
  ('Hip Flexor Stretch', 'Kneeling Hip Flexor Stretch', 'A kneeling stretch that opens the front of the hips.', 'Kneel on one knee with the other foot forward.
Push your hips gently forward until you feel a stretch.
Hold and breathe, then switch legs.', 'Stretching', 'Hips, Quads', 'None', 'beginner', 'stretching', 3.0, 5, 45, 2, 0, 10, 'Squeeze the glute of the back leg to deepen the stretch.
Keep the torso tall.', 'Arching the lower back.
Leaning too far forward.', 'Pad the knee if kneeling on a hard floor.'),
  ('Quad Stretch', 'Standing Quadriceps Stretch', 'A standing stretch that releases the front of the thighs.', 'Stand tall and hold a wall for balance.
Bend one knee and grasp the ankle behind you.
Pull the heel toward the glute and hold, then switch.', 'Stretching', 'Quads, Hips', 'None', 'beginner', 'stretching', 3.0, 5, 45, 2, 0, 10, 'Keep the knees together.
Squeeze the glute to deepen the stretch.', 'Arching the lower back.
Pulling the foot out to the side.', 'Use a wall for balance if needed.
Stop if you feel knee pain.'),
  ('Chest Opener Stretch', 'Wall Chest Stretch', 'A doorway or standing stretch that opens the chest and shoulders.', 'Stand in a doorway and place one forearm on the frame.
Step forward gently until you feel a stretch across the chest.
Hold and breathe, then switch sides.', 'Stretching', 'Chest, Shoulders', 'None', 'beginner', 'stretching', 3.0, 5, 45, 2, 0, 10, 'Keep the elbow at or below shoulder height.
Step forward slowly, don''t push.', 'Elevating the shoulder to the ear.
Pushing too hard and straining.', 'Avoid if you have a recent shoulder injury.'),
  ('Shoulder Stretch', 'Cross-body Shoulder Stretch', 'A simple stretch that relieves tension in the shoulders.', 'Bring one arm straight across your chest.
Use the other hand to pull it gently closer.
Hold and breathe, then switch arms.', 'Stretching', 'Shoulders, Upper Back', 'None', 'beginner', 'stretching', 2.0, 3, 45, 2, 0, 10, 'Keep the shoulder of the stretching arm relaxed.
Breathe out as you deepen the stretch.', 'Shrugging the stretched shoulder.
Pulling too aggressively.', 'Stretch gently and stop at mild tension.'),
  ('Butterfly Stretch', 'Baddha Konasana', 'A seated stretch that opens the hips and inner thighs.', 'Sit with the soles of your feet together.
Hold your feet and gently press the knees down.
Hinge forward from the hips and hold.', 'Stretching', 'Hips, Inner Thighs', 'None', 'beginner', 'stretching', 3.0, 5, 45, 2, 0, 10, 'Press the knees down gently, never force.
Keep the spine long.', 'Bouncing the knees.
Rounding the back.', 'Sit on a cushion for comfort.'),
  ('Downward Dog', 'Adho Mukha Svanasana', 'A foundational yoga pose that lengthens the spine and hamstrings.', 'Start on all fours with hands under shoulders.
Lift your hips up and back to form an inverted V.
Press your heels toward the floor and relax your neck.', 'Yoga', 'Hamstrings, Calves, Shoulders', 'None', 'beginner', 'yoga', 4.0, 6, 45, 2, 0, 10, 'Press firmly through the hands and spread the fingers.
Bend the knees to keep the back long.', 'Rounding the back.
Letting the shoulders collapse to the ears.', 'Keep a slight bend in the knees if hamstrings are tight.'),
  ('Cat-Cow', 'Marjaryasana-Bitilasana', 'A flowing spinal movement that improves mobility and relieves tension.', 'Start on all fours with a neutral spine.
Inhale as you arch your back and lift your head (cow).
Exhale as you round your back and tuck your chin (cat).', 'Yoga', 'Spine, Core, Shoulders', 'None', 'beginner', 'yoga', 3.0, 5, 45, 2, 0, 10, 'Sync each movement with your breath.
Move gently through the full spine.', 'Rushing the movement.
Holding the breath.', 'Keep the movement pain-free.'),
  ('Pigeon Pose', 'Eka Pada Rajakapotasana', 'A deep hip-opening pose that relieves tight glutes and hips.', 'Bring one knee forward and extend the opposite leg behind you.
Square your hips toward the floor.
Fold forward and hold while breathing deeply.', 'Yoga', 'Glutes, Hips, Lower Back', 'None', 'beginner', 'yoga', 3.0, 5, 45, 2, 0, 10, 'Keep the front shin roughly parallel to the mat.
Rest on a cushion if one hip lifts.', 'Letting the hips twist to the side.
Forcing the knee to the floor.', 'Ease out slowly if you feel knee pressure.'),
  ('Bridge Pose', 'Setu Bandhasana', 'A back-strengthening pose that opens the chest and hips.', 'Lie on your back with knees bent and feet flat.
Press through your feet to lift your hips up.
Interlace your hands under your back and hold.', 'Yoga', 'Glutes, Chest, Spine', 'None', 'beginner', 'yoga', 4.0, 6, 45, 2, 0, 10, 'Squeeze the glutes to lift the hips.
Keep the knees hip-width apart.', 'Arching the lower back.
Pushing the knees outward.', 'Lower down slowly and with control.'),
  ('Warrior II', 'Virabhadrasana II', 'A powerful standing pose that builds leg strength and focus.', 'Step your feet wide apart with front knee bent over your ankle.
Extend your arms parallel to the floor.
Look over your front hand and hold the stance.', 'Yoga', 'Legs, Shoulders, Core', 'None', 'intermediate', 'yoga', 4.0, 6, 45, 2, 0, 10, 'Stack the front knee over the ankle.
Keep the back leg straight and grounded.', 'Letting the front knee cave inward.
Leaning the torso forward.', 'Keep the front knee tracking over the toes.'),
  ('Low Lunge', 'Anjaneyasana', 'A lunge-based hip opener that stretches the front of the hip.', 'Step one foot forward into a lunge.
Lower the back knee to the floor.
Lift your arms overhead and sink the hips forward.', 'Yoga', 'Hip Flexors, Quads, Glutes', 'None', 'beginner', 'yoga', 4.0, 6, 45, 2, 0, 10, 'Keep the front knee over the ankle.
Reach tall through the spine.', 'Collapsing the front knee inward.
Hunching the shoulders.', 'Pad the back knee on hard floors.'),
  ('Warrior I', 'Virabhadrasana I', 'A strengthening standing pose that opens the hips and chest.', 'Step into a long stance with the front knee bent.
Turn the back foot out and square the hips forward.
Raise your arms overhead and hold.', 'Yoga', 'Legs, Glutes, Shoulders', 'None', 'beginner', 'yoga', 4.0, 6, 45, 2, 0, 10, 'Sink the hips toward the floor.
Keep the chest lifted.', 'Over-rotating the back hip.
Locking the back knee.', 'Keep a slight bend in the back knee.'),
  ('Tree Pose', 'Vrksasana', 'A balancing pose that builds stability and focus.', 'Stand tall and shift weight onto one foot.
Place the other foot on the inner thigh or calf.
Bring your palms together at the chest and balance.', 'Yoga', 'Legs, Core, Balance', 'None', 'beginner', 'yoga', 3.0, 5, 45, 2, 0, 10, 'Fix your gaze on a steady point.
Press the standing foot into the floor.', 'Pressing the foot into the knee.
Leaning the torso to one side.', 'Place the foot below the knee if balance is difficult.
Use a wall for support.'),
  ('Triangle Pose', 'Trikonasana', 'A lateral stretch that opens the hips, legs and torso.', 'Stand with feet wide and arms extended.
Reach forward, then rotate and lower one hand toward the shin.
Reach the other arm to the ceiling and hold.', 'Yoga', 'Legs, Obliques, Spine', 'None', 'intermediate', 'yoga', 4.0, 6, 45, 2, 0, 10, 'Keep the legs straight but not locked.
Open the chest toward the ceiling.', 'Rounding the back.
Dropping the top arm.', 'Stop if you feel a sharp pull in the hamstring.'),
  ('Seated Spinal Twist', 'Ardha Matsyendrasana', 'A seated twist that improves spinal mobility and releases tension.', 'Sit tall with one leg bent over the other.
Hook the opposite elbow outside the bent knee.
Twist gently from the waist and hold, then switch.', 'Yoga', 'Spine, Obliques, Hips', 'None', 'beginner', 'yoga', 3.0, 5, 45, 2, 0, 10, 'Lengthen the spine before twisting.
Exhale as you rotate.', 'Collapsing the chest.
Forcing the twist with the arm.', 'Keep the twist gentle and pain-free.')on conflict (name) where user_id is null do nothing;

-- -----------------------------------------------------------------------------
-- 5. foods (212 global foods, user_id IS NULL)
-- -----------------------------------------------------------------------------
insert into public.foods (
    name, category, serving_size, serving_grams, calories, protein, carbs, fat,
    fiber, sugar, sodium, potassium, calcium, iron, vitamin_a, vitamin_c,
    water_percentage
)
values

  ('White Rice (Cooked)', 'rice', '1 cup (150g)', 150.0, 205.0, 4.3, 45.0, 0.4, 0.6, 0.1, 2.0, 55.0, 15.0, 1.9, 0.0, 0.0, 69.0),
  ('Brown Rice (Cooked)', 'rice', '1 cup (150g)', 150.0, 218.0, 4.5, 46.0, 1.6, 3.5, 0.7, 8.0, 154.0, 15.0, 1.0, 0.0, 0.0, 70.0),
  ('Basmati Rice (Cooked)', 'rice', '1 cup (140g)', 140.0, 190.0, 4.1, 41.0, 0.4, 0.7, 0.1, 2.0, 42.0, 12.0, 0.9, 0.0, 0.0, 69.0),
  ('Jasmine Rice (Cooked)', 'rice', '1 cup (140g)', 140.0, 181.0, 3.7, 39.0, 0.3, 0.3, 0.0, 2.0, 34.0, 11.0, 0.8, 0.0, 0.0, 69.0),
  ('Fried Rice', 'rice', '1 cup (160g)', 160.0, 238.0, 5.0, 45.0, 4.5, 1.5, 1.0, 620.0, 120.0, 18.0, 1.3, 0.0, 0.0, 62.0),
  ('Rice Porridge (Khichuri)', 'rice', '1 bowl (250g)', 250.0, 210.0, 7.0, 36.0, 4.0, 2.5, 1.0, 480.0, 180.0, 20.0, 1.8, 0.0, 0.0, 74.0),
  ('Chicken Biryani', 'rice', '1 plate (350g)', 350.0, 540.0, 26.0, 60.0, 22.0, 2.0, 2.0, 850.0, 350.0, 35.0, 2.4, 0.0, 0.0, 58.0),
  ('Vegetable Pulao', 'rice', '1 cup (160g)', 160.0, 220.0, 4.5, 40.0, 5.0, 2.0, 1.5, 420.0, 150.0, 18.0, 1.4, 0.0, 0.0, 62.0),
  ('Rice Noodles', 'rice', '1 cup (180g)', 180.0, 192.0, 3.2, 44.0, 0.4, 1.8, 0.5, 10.0, 34.0, 12.0, 0.7, 0.0, 0.0, 71.0),
  ('Rice Cake', 'rice', '1 piece (9g)', 9.0, 35.0, 0.7, 7.0, 0.3, 0.4, 0.0, 30.0, 10.0, 1.0, 0.1, 0.0, 0.0, 6.0),
  ('Black Rice (Cooked)', 'rice', '1 cup (150g)', 150.0, 200.0, 5.0, 43.0, 1.5, 3.0, 0.5, 5.0, 120.0, 13.0, 1.6, 0.0, 0.0, 70.0),
  ('Wild Rice (Cooked)', 'rice', '1 cup (165g)', 165.0, 166.0, 6.5, 35.0, 0.6, 3.0, 1.0, 5.0, 170.0, 7.0, 0.9, 0.0, 0.0, 75.0),
  ('Sticky Rice (Cooked)', 'rice', '1 cup (150g)', 150.0, 170.0, 3.2, 37.0, 0.3, 1.0, 0.1, 5.0, 25.0, 8.0, 0.5, 0.0, 0.0, 60.0),
  ('White Bread', 'bread', '1 slice (25g)', 25.0, 67.0, 2.0, 13.0, 0.8, 0.6, 1.4, 130.0, 25.0, 35.0, 0.9, 0.0, 0.0, 36.0),
  ('Whole Wheat Bread', 'bread', '1 slice (28g)', 28.0, 69.0, 3.6, 12.0, 1.1, 1.9, 1.4, 130.0, 69.0, 30.0, 0.7, 0.0, 0.0, 38.0),
  ('Brown Bread', 'bread', '1 slice (26g)', 26.0, 66.0, 2.5, 12.0, 0.9, 1.2, 1.3, 125.0, 45.0, 32.0, 0.8, 0.0, 0.0, 38.0),
  ('Multigrain Bread', 'bread', '1 slice (28g)', 28.0, 70.0, 3.4, 12.0, 1.1, 2.0, 1.3, 120.0, 60.0, 28.0, 0.8, 0.0, 0.0, 37.0),
  ('Rye Bread', 'bread', '1 slice (32g)', 32.0, 83.0, 2.7, 15.0, 1.1, 2.2, 1.3, 151.0, 54.0, 10.0, 0.7, 0.0, 0.0, 38.0),
  ('Pita Bread', 'bread', '1 piece (60g)', 60.0, 165.0, 5.5, 33.0, 0.7, 1.4, 0.5, 300.0, 70.0, 25.0, 1.3, 0.0, 0.0, 30.0),
  ('Naan', 'bread', '1 piece (90g)', 90.0, 260.0, 9.0, 45.0, 5.0, 2.0, 3.0, 350.0, 90.0, 40.0, 1.5, 0.0, 0.0, 32.0),
  ('Roti (Chapati)', 'bread', '1 piece (40g)', 40.0, 120.0, 3.5, 24.0, 1.0, 3.0, 0.3, 200.0, 60.0, 10.0, 1.0, 0.0, 0.0, 30.0),
  ('Paratha', 'bread', '1 piece (55g)', 55.0, 240.0, 4.0, 28.0, 13.0, 1.5, 0.5, 330.0, 60.0, 12.0, 1.1, 0.0, 0.0, 25.0),
  ('Bagel', 'bread', '1 piece (100g)', 100.0, 257.0, 10.0, 50.0, 1.5, 2.0, 5.0, 440.0, 90.0, 20.0, 2.4, 0.0, 0.0, 35.0),
  ('Croissant', 'bread', '1 piece (57g)', 57.0, 231.0, 5.0, 26.0, 12.0, 1.5, 6.0, 260.0, 70.0, 20.0, 1.2, 0.0, 0.0, 25.0),
  ('Burger Bun', 'bread', '1 piece (50g)', 50.0, 140.0, 4.5, 26.0, 2.5, 1.2, 4.0, 260.0, 50.0, 40.0, 1.2, 0.0, 0.0, 33.0),
  ('Gluten Free Bread', 'bread', '1 slice (30g)', 30.0, 80.0, 1.5, 15.0, 1.5, 1.0, 1.5, 140.0, 20.0, 25.0, 0.4, 0.0, 0.0, 40.0),
  ('Beef Steak', 'meat', '100g', 100.0, 271.0, 25.0, 0.0, 19.0, 0.0, 0.0, 60.0, 340.0, 12.0, 2.6, 0.0, 0.0, 60.0),
  ('Lean Ground Beef', 'meat', '100g', 100.0, 250.0, 26.0, 0.0, 15.0, 0.0, 0.0, 75.0, 330.0, 14.0, 2.4, 0.0, 0.0, 62.0),
  ('Beef Curry', 'meat', '1 bowl (200g)', 200.0, 350.0, 28.0, 8.0, 22.0, 1.5, 2.0, 700.0, 400.0, 25.0, 3.2, 0.0, 0.0, 60.0),
  ('Beef Liver', 'meat', '100g', 100.0, 175.0, 26.0, 5.0, 4.0, 0.0, 0.0, 69.0, 310.0, 6.0, 6.5, 7740.0, 1.0, 69.0),
  ('Lamb Chop', 'meat', '100g', 100.0, 294.0, 25.0, 0.0, 21.0, 0.0, 0.0, 65.0, 290.0, 17.0, 1.9, 0.0, 0.0, 58.0),
  ('Lamb Curry', 'meat', '1 bowl (200g)', 200.0, 380.0, 30.0, 9.0, 25.0, 1.5, 2.0, 680.0, 380.0, 30.0, 2.8, 0.0, 0.0, 58.0),
  ('Pork Chop', 'meat', '100g', 100.0, 231.0, 25.0, 0.0, 14.0, 0.0, 0.0, 62.0, 320.0, 15.0, 0.8, 0.0, 0.0, 58.0),
  ('Pork Bacon', 'meat', '2 slices (20g)', 20.0, 90.0, 6.0, 0.3, 7.0, 0.0, 0.2, 350.0, 65.0, 2.0, 0.3, 0.0, 0.0, 30.0),
  ('Mutton Curry', 'meat', '1 bowl (200g)', 200.0, 360.0, 29.0, 8.0, 24.0, 1.5, 2.0, 700.0, 360.0, 28.0, 3.5, 0.0, 0.0, 57.0),
  ('Beef Kebab', 'meat', '1 skewer (80g)', 80.0, 210.0, 18.0, 2.0, 14.0, 0.5, 0.5, 480.0, 240.0, 10.0, 2.2, 0.0, 0.0, 58.0),
  ('Veal', 'meat', '100g', 100.0, 172.0, 31.0, 0.0, 5.0, 0.0, 0.0, 86.0, 320.0, 9.0, 0.9, 0.0, 0.0, 68.0),
  ('Pork Sausage', 'meat', '1 link (75g)', 75.0, 260.0, 13.0, 2.0, 22.0, 0.0, 1.0, 620.0, 150.0, 15.0, 0.9, 0.0, 0.0, 52.0),
  ('Ham', 'meat', '100g', 100.0, 145.0, 20.0, 1.5, 5.5, 0.0, 1.0, 1000.0, 290.0, 8.0, 1.2, 0.0, 0.0, 65.0),
  ('Corned Beef', 'meat', '100g', 100.0, 251.0, 22.0, 0.0, 18.0, 0.0, 0.0, 970.0, 250.0, 9.0, 2.6, 0.0, 0.0, 55.0),
  ('Chicken Breast (Grilled)', 'chicken', '100g', 100.0, 165.0, 31.0, 0.0, 3.6, 0.0, 0.0, 74.0, 340.0, 15.0, 1.0, 0.0, 0.0, 65.0),
  ('Chicken Thigh (Roasted)', 'chicken', '100g', 100.0, 209.0, 26.0, 0.0, 11.0, 0.0, 0.0, 86.0, 280.0, 12.0, 1.3, 0.0, 0.0, 62.0),
  ('Chicken Drumstick', 'chicken', '1 piece (90g)', 90.0, 165.0, 21.0, 0.0, 8.0, 0.0, 0.0, 90.0, 210.0, 10.0, 1.1, 0.0, 0.0, 62.0),
  ('Chicken Wing', 'chicken', '1 piece (60g)', 60.0, 146.0, 12.0, 0.0, 10.0, 0.0, 0.0, 80.0, 140.0, 8.0, 0.8, 0.0, 0.0, 56.0),
  ('Chicken Curry', 'chicken', '1 bowl (200g)', 200.0, 310.0, 28.0, 7.0, 18.0, 1.0, 2.0, 650.0, 380.0, 24.0, 1.8, 0.0, 0.0, 60.0),
  ('Butter Chicken', 'chicken', '1 bowl (250g)', 250.0, 500.0, 32.0, 12.0, 36.0, 1.0, 6.0, 800.0, 380.0, 80.0, 2.2, 0.0, 0.0, 55.0),
  ('Chicken Tikka', 'chicken', '100g', 100.0, 190.0, 25.0, 4.0, 8.0, 0.5, 2.0, 520.0, 300.0, 22.0, 1.4, 0.0, 0.0, 62.0),
  ('Chicken Kebab', 'chicken', '1 skewer (80g)', 80.0, 160.0, 20.0, 2.0, 8.0, 0.3, 0.5, 400.0, 220.0, 12.0, 1.1, 0.0, 0.0, 62.0),
  ('Chicken Liver', 'chicken', '100g', 100.0, 185.0, 25.0, 1.0, 8.0, 0.0, 0.0, 70.0, 250.0, 10.0, 8.0, 3600.0, 17.0, 68.0),
  ('Fried Chicken', 'chicken', '1 piece (120g)', 120.0, 320.0, 20.0, 12.0, 22.0, 0.5, 1.0, 480.0, 220.0, 20.0, 1.2, 0.0, 0.0, 45.0),
  ('Chicken Biryani (Leg Piece)', 'chicken', '1 plate (350g)', 350.0, 520.0, 24.0, 62.0, 20.0, 2.0, 2.0, 820.0, 340.0, 32.0, 2.2, 0.0, 0.0, 58.0),
  ('Chicken Soup', 'chicken', '1 bowl (240g)', 240.0, 120.0, 10.0, 8.0, 5.0, 0.5, 1.0, 600.0, 200.0, 15.0, 0.9, 0.0, 0.0, 88.0),
  ('Salmon (Grilled)', 'fish', '100g', 100.0, 208.0, 20.0, 0.0, 13.0, 0.0, 0.0, 59.0, 363.0, 9.0, 0.3, 40.0, 3.9, 68.0),
  ('Tuna (Canned in Water)', 'fish', '100g', 100.0, 116.0, 25.0, 0.0, 1.0, 0.0, 0.0, 320.0, 240.0, 10.0, 1.2, 0.0, 0.0, 72.0),
  ('Tilapia', 'fish', '100g', 100.0, 128.0, 26.0, 0.0, 3.0, 0.0, 0.0, 52.0, 300.0, 10.0, 0.6, 0.0, 0.0, 70.0),
  ('Hilsa (Cooked)', 'fish', '100g', 100.0, 250.0, 21.0, 0.0, 18.0, 0.0, 0.0, 60.0, 300.0, 120.0, 1.3, 0.0, 0.0, 62.0),
  ('Rohu Fish (Cooked)', 'fish', '100g', 100.0, 130.0, 19.0, 0.0, 6.0, 0.0, 0.0, 55.0, 280.0, 60.0, 0.8, 0.0, 0.0, 70.0),
  ('Catla Fish (Cooked)', 'fish', '100g', 100.0, 140.0, 18.0, 0.0, 7.0, 0.0, 0.0, 55.0, 270.0, 55.0, 0.7, 0.0, 0.0, 70.0),
  ('Mackerel', 'fish', '100g', 100.0, 205.0, 19.0, 0.0, 14.0, 0.0, 0.0, 70.0, 280.0, 12.0, 1.6, 0.0, 0.0, 66.0),
  ('Sardines', 'fish', '100g', 100.0, 208.0, 25.0, 0.0, 11.0, 0.0, 0.0, 300.0, 400.0, 380.0, 2.5, 32.0, 0.0, 64.0),
  ('Cod', 'fish', '100g', 100.0, 82.0, 18.0, 0.0, 0.7, 0.0, 0.0, 54.0, 340.0, 16.0, 0.4, 0.0, 0.0, 78.0),
  ('Trout', 'fish', '100g', 100.0, 149.0, 21.0, 0.0, 7.0, 0.0, 0.0, 51.0, 360.0, 18.0, 0.3, 0.0, 0.0, 73.0),
  ('Pomfret (Cooked)', 'fish', '100g', 100.0, 175.0, 19.0, 0.0, 11.0, 0.0, 0.0, 60.0, 300.0, 40.0, 0.8, 0.0, 0.0, 65.0),
  ('Prawns (Shrimp)', 'fish', '100g', 100.0, 99.0, 24.0, 0.2, 0.3, 0.0, 0.0, 111.0, 259.0, 70.0, 0.5, 0.0, 0.0, 75.0),
  ('Crab', 'fish', '100g', 100.0, 97.0, 19.0, 0.0, 1.5, 0.0, 0.0, 380.0, 260.0, 90.0, 0.7, 0.0, 0.0, 78.0),
  ('Squid (Calamari)', 'fish', '100g', 100.0, 92.0, 16.0, 3.0, 1.4, 0.0, 0.0, 45.0, 250.0, 30.0, 0.7, 0.0, 0.0, 78.0),
  ('Whole Egg (Boiled)', 'egg', '1 egg (50g)', 50.0, 78.0, 6.3, 0.6, 5.3, 0.0, 0.6, 62.0, 63.0, 25.0, 0.6, 80.0, 0.0, 75.0),
  ('Egg White', 'egg', '1 egg (33g)', 33.0, 17.0, 3.6, 0.2, 0.0, 0.0, 0.2, 55.0, 54.0, 2.0, 0.0, 0.0, 0.0, 88.0),
  ('Egg Yolk', 'egg', '1 yolk (17g)', 17.0, 55.0, 2.7, 0.6, 4.5, 0.0, 0.0, 8.0, 19.0, 22.0, 0.5, 109.0, 0.0, 52.0),
  ('Fried Egg', 'egg', '1 egg (50g)', 50.0, 92.0, 6.3, 0.4, 7.0, 0.0, 0.4, 95.0, 68.0, 25.0, 0.7, 90.0, 0.0, 72.0),
  ('Omelette', 'egg', '1 (60g)', 60.0, 110.0, 7.0, 1.0, 8.5, 0.2, 0.8, 180.0, 80.0, 35.0, 0.8, 110.0, 0.0, 70.0),
  ('Scrambled Eggs', 'egg', '2 eggs (100g)', 100.0, 180.0, 12.0, 2.0, 14.0, 0.0, 2.0, 300.0, 140.0, 50.0, 1.3, 180.0, 0.0, 68.0),
  ('Boiled Egg (2)', 'egg', '2 eggs (100g)', 100.0, 155.0, 12.6, 1.1, 10.6, 0.0, 1.1, 124.0, 126.0, 50.0, 1.2, 160.0, 0.0, 75.0),
  ('Broccoli (Steamed)', 'vegetables', '1 cup (90g)', 90.0, 31.0, 2.5, 6.0, 0.4, 2.4, 1.5, 30.0, 290.0, 43.0, 0.7, 42.0, 81.0, 89.0),
  ('Spinach (Cooked)', 'vegetables', '1 cup (180g)', 180.0, 41.0, 5.3, 6.8, 0.5, 4.3, 0.8, 126.0, 839.0, 245.0, 6.4, 1410.0, 17.0, 91.0),
  ('Carrot (Raw)', 'vegetables', '1 medium (61g)', 61.0, 25.0, 0.6, 6.0, 0.1, 1.7, 2.9, 42.0, 195.0, 20.0, 0.2, 509.0, 3.6, 88.0),
  ('Tomato', 'vegetables', '1 medium (123g)', 123.0, 22.0, 1.1, 4.8, 0.2, 1.5, 3.2, 6.0, 292.0, 12.0, 0.3, 50.0, 16.0, 94.0),
  ('Potato (Boiled)', 'vegetables', '1 medium (150g)', 150.0, 129.0, 2.9, 30.0, 0.2, 3.0, 1.5, 8.0, 506.0, 12.0, 0.5, 0.0, 21.0, 77.0),
  ('Sweet Potato (Baked)', 'vegetables', '1 medium (114g)', 114.0, 103.0, 2.3, 24.0, 0.2, 3.8, 7.4, 41.0, 475.0, 43.0, 0.7, 1094.0, 22.0, 77.0),
  ('Cauliflower (Cooked)', 'vegetables', '1 cup (120g)', 120.0, 27.0, 2.0, 5.0, 0.5, 2.0, 2.0, 20.0, 175.0, 20.0, 0.5, 0.0, 55.0, 92.0),
  ('Cabbage (Shredded)', 'vegetables', '1 cup (90g)', 90.0, 22.0, 1.1, 5.0, 0.1, 2.2, 2.8, 16.0, 151.0, 36.0, 0.4, 0.0, 33.0, 92.0),
  ('Capsicum (Bell Pepper)', 'vegetables', '1 medium (119g)', 119.0, 24.0, 1.0, 6.0, 0.2, 2.1, 3.0, 4.0, 208.0, 9.0, 0.5, 69.0, 95.0, 94.0),
  ('Cucumber', 'vegetables', '1 cup (104g)', 104.0, 16.0, 0.7, 3.8, 0.1, 0.5, 1.7, 2.0, 147.0, 16.0, 0.3, 0.0, 2.8, 95.0),
  ('Onion (Raw)', 'vegetables', '1 medium (110g)', 110.0, 44.0, 1.2, 10.0, 0.1, 1.9, 4.7, 4.0, 161.0, 25.0, 0.2, 0.0, 8.0, 89.0),
  ('Garlic', 'vegetables', '3 cloves (9g)', 9.0, 13.0, 0.6, 3.0, 0.0, 0.2, 0.1, 1.0, 36.0, 16.0, 0.2, 0.0, 2.7, 59.0),
  ('Green Beans (Cooked)', 'vegetables', '1 cup (125g)', 125.0, 44.0, 2.4, 10.0, 0.3, 4.0, 4.6, 7.0, 183.0, 33.0, 1.1, 0.0, 12.0, 90.0),
  ('Green Peas (Cooked)', 'vegetables', '1 cup (160g)', 160.0, 134.0, 8.6, 25.0, 0.4, 8.8, 9.4, 4.0, 340.0, 40.0, 2.5, 0.0, 28.0, 78.0),
  ('Mushroom (Cooked)', 'vegetables', '1 cup (90g)', 90.0, 26.0, 2.0, 5.0, 0.4, 2.0, 2.0, 5.0, 296.0, 3.0, 0.8, 0.0, 0.0, 91.0),
  ('Pumpkin (Cooked)', 'vegetables', '1 cup (245g)', 245.0, 49.0, 2.0, 12.0, 0.2, 3.0, 5.0, 2.0, 564.0, 37.0, 1.4, 882.0, 12.0, 94.0),
  ('Corn (Sweet, Cooked)', 'vegetables', '1 ear (90g)', 90.0, 90.0, 3.0, 19.0, 1.3, 2.3, 3.2, 12.0, 240.0, 4.0, 0.5, 0.0, 6.0, 70.0),
  ('Eggplant (Cooked)', 'vegetables', '1 cup (99g)', 99.0, 35.0, 0.8, 9.0, 0.2, 2.5, 3.0, 2.0, 188.0, 6.0, 0.3, 0.0, 0.0, 90.0),
  ('Zucchini (Cooked)', 'vegetables', '1 cup (180g)', 180.0, 27.0, 1.4, 6.0, 0.4, 2.0, 3.0, 9.0, 380.0, 30.0, 0.7, 0.0, 18.0, 94.0),
  ('Apple', 'fruits', '1 medium (182g)', 182.0, 95.0, 0.5, 25.0, 0.3, 4.4, 19.0, 2.0, 195.0, 11.0, 0.2, 0.0, 8.4, 86.0),
  ('Banana', 'fruits', '1 medium (118g)', 118.0, 105.0, 1.3, 27.0, 0.4, 3.1, 14.0, 1.0, 422.0, 6.0, 0.3, 0.0, 10.0, 75.0),
  ('Orange', 'fruits', '1 medium (131g)', 131.0, 62.0, 1.2, 15.0, 0.2, 3.1, 12.0, 0.0, 237.0, 52.0, 0.1, 0.0, 70.0, 87.0),
  ('Mango', 'fruits', '1 cup (165g)', 165.0, 99.0, 1.4, 25.0, 0.6, 2.6, 23.0, 2.0, 277.0, 18.0, 0.3, 178.0, 60.0, 83.0),
  ('Grapes', 'fruits', '1 cup (151g)', 151.0, 104.0, 1.1, 27.0, 0.2, 1.4, 23.0, 3.0, 288.0, 15.0, 0.5, 0.0, 5.0, 81.0),
  ('Watermelon', 'fruits', '1 cup (152g)', 152.0, 46.0, 0.9, 12.0, 0.2, 0.6, 9.0, 1.0, 170.0, 11.0, 0.4, 43.0, 12.0, 92.0),
  ('Papaya', 'fruits', '1 cup (145g)', 145.0, 62.0, 0.7, 16.0, 0.4, 2.5, 11.0, 9.0, 263.0, 31.0, 0.4, 68.0, 87.0, 88.0),
  ('Guava', 'fruits', '1 fruit (100g)', 100.0, 68.0, 2.6, 14.0, 0.9, 5.4, 9.0, 2.0, 417.0, 18.0, 0.3, 0.0, 228.0, 81.0),
  ('Pineapple', 'fruits', '1 cup (165g)', 165.0, 82.0, 0.9, 22.0, 0.2, 2.3, 16.0, 2.0, 180.0, 21.0, 0.5, 0.0, 79.0, 86.0),
  ('Strawberries', 'fruits', '1 cup (152g)', 152.0, 49.0, 1.0, 12.0, 0.5, 3.0, 7.4, 1.0, 233.0, 24.0, 0.6, 0.0, 89.0, 91.0),
  ('Blueberries', 'fruits', '1 cup (148g)', 148.0, 84.0, 1.1, 21.0, 0.5, 3.6, 15.0, 1.0, 114.0, 9.0, 0.4, 0.0, 14.0, 84.0),
  ('Litchi', 'fruits', '1 cup (190g)', 190.0, 125.0, 1.6, 31.0, 0.8, 2.5, 29.0, 1.0, 325.0, 10.0, 0.6, 0.0, 136.0, 82.0),
  ('Jackfruit', 'fruits', '1 cup (165g)', 165.0, 155.0, 2.4, 38.0, 1.1, 2.5, 32.0, 3.0, 739.0, 34.0, 0.4, 0.0, 22.0, 73.0),
  ('Pomegranate', 'fruits', '1/2 fruit (87g)', 87.0, 72.0, 1.5, 16.0, 1.0, 3.5, 12.0, 2.0, 205.0, 9.0, 0.3, 0.0, 9.0, 81.0),
  ('Kiwi', 'fruits', '1 fruit (69g)', 69.0, 42.0, 0.8, 10.0, 0.4, 2.1, 6.0, 2.0, 215.0, 23.0, 0.2, 0.0, 64.0, 83.0),
  ('Pear', 'fruits', '1 medium (178g)', 178.0, 101.0, 0.6, 27.0, 0.2, 5.5, 17.0, 1.0, 206.0, 16.0, 0.2, 0.0, 7.0, 84.0),
  ('Peach', 'fruits', '1 medium (150g)', 150.0, 59.0, 1.4, 14.0, 0.4, 2.3, 12.0, 0.0, 285.0, 10.0, 0.4, 24.0, 10.0, 89.0),
  ('Lemon', 'fruits', '1 fruit (58g)', 58.0, 17.0, 0.6, 5.0, 0.2, 1.6, 1.5, 1.0, 80.0, 15.0, 0.4, 0.0, 31.0, 89.0),
  ('Dates', 'fruits', '3 dates (24g)', 24.0, 66.0, 0.5, 18.0, 0.0, 1.9, 16.0, 0.0, 167.0, 16.0, 0.2, 0.0, 0.0, 20.0),
  ('Avocado', 'fruits', '1/2 fruit (100g)', 100.0, 160.0, 2.0, 8.5, 14.7, 6.7, 0.7, 7.0, 485.0, 12.0, 0.6, 7.0, 10.0, 73.0),
  ('Whole Milk', 'milk', '1 cup (244g)', 244.0, 149.0, 7.7, 12.0, 8.0, 0.0, 12.0, 105.0, 322.0, 276.0, 0.1, 56.0, 0.0, 87.0),
  ('Low Fat Milk (2%)', 'milk', '1 cup (244g)', 244.0, 122.0, 8.1, 12.0, 4.8, 0.0, 12.0, 107.0, 366.0, 293.0, 0.1, 64.0, 0.0, 89.0),
  ('Skim Milk', 'milk', '1 cup (245g)', 245.0, 83.0, 8.3, 12.0, 0.2, 0.0, 12.0, 103.0, 382.0, 299.0, 0.1, 62.0, 0.0, 91.0),
  ('Soy Milk', 'milk', '1 cup (243g)', 243.0, 80.0, 7.0, 4.0, 4.0, 1.0, 1.0, 90.0, 300.0, 300.0, 1.0, 0.0, 0.0, 90.0),
  ('Almond Milk', 'milk', '1 cup (240g)', 240.0, 39.0, 1.0, 3.4, 2.5, 0.5, 2.0, 189.0, 220.0, 482.0, 0.7, 0.0, 0.0, 93.0),
  ('Oat Milk', 'milk', '1 cup (240g)', 240.0, 120.0, 3.0, 16.0, 5.0, 2.0, 7.0, 100.0, 180.0, 350.0, 1.0, 0.0, 0.0, 90.0),
  ('Condensed Milk', 'milk', '2 tbsp (38g)', 38.0, 123.0, 3.1, 21.0, 3.3, 0.0, 21.0, 51.0, 127.0, 106.0, 0.1, 0.0, 0.0, 27.0),
  ('Buttermilk', 'milk', '1 cup (245g)', 245.0, 98.0, 8.0, 12.0, 2.5, 0.0, 12.0, 257.0, 345.0, 282.0, 0.1, 40.0, 0.0, 90.0),
  ('Lassi (Sweet)', 'milk', '1 cup (240g)', 240.0, 160.0, 6.0, 26.0, 4.0, 0.0, 22.0, 80.0, 320.0, 240.0, 0.1, 0.0, 0.0, 85.0),
  ('Greek Yogurt (Plain)', 'dairy', '1 cup (245g)', 245.0, 130.0, 22.0, 9.0, 0.7, 0.0, 9.0, 65.0, 240.0, 250.0, 0.0, 0.0, 0.0, 82.0),
  ('Plain Yogurt (Full Fat)', 'dairy', '1 cup (245g)', 245.0, 149.0, 8.5, 11.0, 8.0, 0.0, 11.0, 113.0, 380.0, 296.0, 0.1, 34.0, 0.0, 88.0),
  ('Cheddar Cheese', 'dairy', '1 slice (28g)', 28.0, 114.0, 6.4, 0.4, 9.4, 0.0, 0.1, 181.0, 28.0, 202.0, 0.1, 70.0, 0.0, 37.0),
  ('Mozzarella Cheese', 'dairy', '1/4 cup (28g)', 28.0, 85.0, 6.3, 0.6, 6.3, 0.0, 0.2, 178.0, 24.0, 143.0, 0.0, 0.0, 0.0, 50.0),
  ('Cottage Cheese', 'dairy', '1 cup (226g)', 226.0, 163.0, 28.0, 6.0, 2.3, 0.0, 5.0, 706.0, 194.0, 227.0, 0.2, 0.0, 0.0, 79.0),
  ('Cream Cheese', 'dairy', '2 tbsp (29g)', 29.0, 102.0, 1.8, 1.5, 10.0, 0.0, 1.0, 87.0, 34.0, 23.0, 0.0, 91.0, 0.0, 53.0),
  ('Parmesan Cheese', 'dairy', '1 tbsp (10g)', 10.0, 42.0, 3.8, 0.3, 2.8, 0.0, 0.1, 152.0, 9.0, 110.0, 0.0, 0.0, 0.0, 18.0),
  ('Butter', 'dairy', '1 tbsp (14g)', 14.0, 102.0, 0.1, 0.0, 11.5, 0.0, 0.0, 91.0, 3.0, 3.0, 0.0, 97.0, 0.0, 16.0),
  ('Heavy Cream', 'dairy', '2 tbsp (30g)', 30.0, 103.0, 0.6, 0.8, 11.0, 0.0, 0.8, 11.0, 29.0, 23.0, 0.0, 130.0, 0.0, 58.0),
  ('Ice Cream (Vanilla)', 'dairy', '1 scoop (66g)', 66.0, 137.0, 2.3, 16.0, 7.3, 0.5, 14.0, 53.0, 132.0, 84.0, 0.1, 90.0, 0.0, 61.0),
  ('Hamburger', 'fastFood', '1 burger (105g)', 105.0, 250.0, 13.0, 31.0, 9.0, 1.5, 6.0, 480.0, 240.0, 60.0, 2.4, 0.0, 0.0, 55.0),
  ('Cheeseburger', 'fastFood', '1 burger (114g)', 114.0, 303.0, 15.0, 31.0, 14.0, 1.5, 6.0, 510.0, 230.0, 90.0, 2.5, 0.0, 0.0, 53.0),
  ('Chicken Burger', 'fastFood', '1 burger (170g)', 170.0, 460.0, 22.0, 40.0, 24.0, 2.0, 7.0, 800.0, 300.0, 80.0, 1.8, 0.0, 0.0, 50.0),
  ('French Fries', 'fastFood', 'medium (117g)', 117.0, 365.0, 4.0, 48.0, 17.0, 4.3, 0.3, 246.0, 579.0, 12.0, 1.5, 0.0, 14.0, 55.0),
  ('Pizza Slice (Cheese)', 'fastFood', '1 slice (107g)', 107.0, 285.0, 12.0, 36.0, 10.0, 2.5, 3.8, 640.0, 190.0, 170.0, 1.8, 0.0, 0.0, 46.0),
  ('Hot Dog', 'fastFood', '1 (98g)', 98.0, 290.0, 10.0, 24.0, 17.0, 1.0, 5.0, 720.0, 150.0, 30.0, 1.2, 0.0, 0.0, 55.0),
  ('Shawarma Wrap', 'fastFood', '1 wrap (280g)', 280.0, 620.0, 30.0, 55.0, 30.0, 4.0, 5.0, 900.0, 400.0, 120.0, 3.0, 0.0, 0.0, 50.0),
  ('Fried Fish Fillet', 'fastFood', '1 fillet (85g)', 85.0, 240.0, 15.0, 15.0, 13.0, 1.0, 1.0, 400.0, 260.0, 20.0, 0.8, 0.0, 0.0, 55.0),
  ('Samosa', 'fastFood', '1 piece (75g)', 75.0, 190.0, 4.0, 22.0, 10.0, 1.5, 1.0, 280.0, 150.0, 12.0, 0.9, 0.0, 0.0, 40.0),
  ('Spring Roll', 'fastFood', '1 piece (50g)', 50.0, 120.0, 3.0, 12.0, 7.0, 1.0, 1.0, 250.0, 80.0, 10.0, 0.5, 0.0, 0.0, 45.0),
  ('Chicken Nuggets', 'fastFood', '6 pieces (96g)', 96.0, 280.0, 14.0, 17.0, 18.0, 1.0, 1.0, 600.0, 230.0, 20.0, 1.0, 0.0, 0.0, 50.0),
  ('Nachos with Cheese', 'fastFood', '1 plate (150g)', 150.0, 450.0, 12.0, 48.0, 24.0, 5.0, 3.0, 700.0, 300.0, 200.0, 1.5, 0.0, 0.0, 45.0),
  ('Pasta Carbonara', 'fastFood', '1 bowl (250g)', 250.0, 520.0, 18.0, 55.0, 25.0, 3.0, 3.0, 800.0, 250.0, 100.0, 2.0, 0.0, 0.0, 62.0),
  ('Chicken Chowmein', 'fastFood', '1 bowl (300g)', 300.0, 480.0, 22.0, 60.0, 18.0, 4.0, 6.0, 950.0, 350.0, 50.0, 2.5, 0.0, 0.0, 60.0),
  ('Chocolate Cake', 'dessert', '1 slice (100g)', 100.0, 370.0, 4.5, 52.0, 16.0, 2.0, 38.0, 280.0, 150.0, 60.0, 1.5, 0.0, 0.0, 27.0),
  ('Vanilla Cake', 'dessert', '1 slice (90g)', 90.0, 320.0, 3.5, 48.0, 13.0, 0.5, 32.0, 250.0, 100.0, 70.0, 0.8, 0.0, 0.0, 26.0),
  ('Glazed Donut', 'dessert', '1 (60g)', 60.0, 240.0, 3.0, 28.0, 13.0, 0.8, 15.0, 210.0, 70.0, 15.0, 1.0, 0.0, 0.0, 22.0),
  ('Chocolate Brownie', 'dessert', '1 (50g)', 50.0, 220.0, 2.5, 28.0, 12.0, 1.5, 20.0, 150.0, 90.0, 25.0, 1.2, 0.0, 0.0, 18.0),
  ('Chocolate Chip Cookie', 'dessert', '1 (20g)', 20.0, 95.0, 1.0, 12.0, 5.0, 0.5, 7.0, 80.0, 35.0, 8.0, 0.4, 0.0, 0.0, 5.0),
  ('Blueberry Muffin', 'dessert', '1 (110g)', 110.0, 350.0, 5.0, 50.0, 15.0, 1.5, 25.0, 300.0, 120.0, 60.0, 1.2, 0.0, 0.0, 30.0),
  ('Pancakes', 'dessert', '2 (110g)', 110.0, 260.0, 7.0, 40.0, 8.0, 1.5, 12.0, 480.0, 150.0, 90.0, 1.5, 0.0, 0.0, 45.0),
  ('Waffle', 'dessert', '1 (80g)', 80.0, 240.0, 6.0, 30.0, 11.0, 1.0, 8.0, 420.0, 120.0, 100.0, 1.4, 0.0, 0.0, 40.0),
  ('Custard', 'dessert', '1 cup (245g)', 245.0, 190.0, 6.0, 28.0, 6.0, 0.0, 24.0, 120.0, 250.0, 200.0, 0.2, 0.0, 0.0, 74.0),
  ('Rice Pudding (Kheer)', 'dessert', '1 bowl (200g)', 200.0, 220.0, 5.0, 35.0, 7.0, 0.5, 22.0, 90.0, 150.0, 120.0, 0.5, 0.0, 0.0, 70.0),
  ('Jalebi', 'dessert', '1 piece (60g)', 60.0, 240.0, 2.0, 40.0, 9.0, 0.5, 35.0, 10.0, 60.0, 10.0, 0.8, 0.0, 0.0, 15.0),
  ('Gulab Jamun', 'dessert', '2 pieces (80g)', 80.0, 270.0, 3.0, 40.0, 12.0, 0.5, 32.0, 80.0, 90.0, 50.0, 0.6, 0.0, 0.0, 25.0),
  ('Rasgulla', 'dessert', '2 pieces (90g)', 90.0, 180.0, 4.0, 36.0, 2.0, 0.0, 30.0, 50.0, 80.0, 90.0, 0.2, 0.0, 0.0, 62.0),
  ('Dark Chocolate', 'dessert', '2 squares (30g)', 30.0, 170.0, 2.3, 13.0, 12.0, 3.4, 7.0, 7.0, 170.0, 13.0, 3.4, 0.0, 0.0, 1.0),
  ('Water', 'drinks', '1 glass (250ml)', 250.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 0.0, 7.0, 0.0, 0.0, 0.0, 100.0),
  ('Orange Juice', 'drinks', '1 cup (248g)', 248.0, 112.0, 1.7, 26.0, 0.5, 0.5, 21.0, 2.0, 496.0, 27.0, 0.5, 0.0, 124.0, 88.0),
  ('Apple Juice', 'drinks', '1 cup (248g)', 248.0, 114.0, 0.2, 28.0, 0.3, 0.5, 24.0, 10.0, 250.0, 20.0, 0.6, 0.0, 2.0, 88.0),
  ('Mango Juice', 'drinks', '1 cup (250g)', 250.0, 130.0, 0.5, 32.0, 0.3, 0.5, 28.0, 8.0, 140.0, 15.0, 0.3, 0.0, 30.0, 87.0),
  ('Lemonade', 'drinks', '1 cup (240g)', 240.0, 99.0, 0.0, 26.0, 0.0, 0.0, 25.0, 10.0, 15.0, 3.0, 0.1, 0.0, 10.0, 89.0),
  ('Iced Tea', 'drinks', '1 cup (240g)', 240.0, 90.0, 0.0, 23.0, 0.0, 0.0, 22.0, 8.0, 12.0, 2.0, 0.1, 0.0, 0.0, 90.0),
  ('Green Tea', 'drinks', '1 cup (240g)', 240.0, 2.0, 0.0, 0.4, 0.0, 0.0, 0.0, 5.0, 20.0, 2.0, 0.0, 0.0, 0.0, 99.0),
  ('Black Coffee', 'drinks', '1 cup (240g)', 240.0, 2.0, 0.3, 0.0, 0.0, 0.0, 0.0, 5.0, 116.0, 5.0, 0.0, 0.0, 0.0, 99.0),
  ('Latte', 'drinks', '1 cup (300g)', 300.0, 150.0, 8.0, 15.0, 6.0, 0.0, 14.0, 140.0, 400.0, 250.0, 0.2, 0.0, 0.0, 90.0),
  ('Cappuccino', 'drinks', '1 cup (240g)', 240.0, 80.0, 4.0, 8.0, 3.5, 0.0, 7.0, 80.0, 200.0, 130.0, 0.1, 0.0, 0.0, 92.0),
  ('Cola', 'drinks', '1 can (330ml)', 330.0, 139.0, 0.0, 39.0, 0.0, 0.0, 39.0, 14.0, 3.0, 0.0, 0.0, 0.0, 0.0, 89.0),
  ('Diet Cola', 'drinks', '1 can (330ml)', 330.0, 1.0, 0.0, 0.2, 0.0, 0.0, 0.0, 20.0, 4.0, 0.0, 0.0, 0.0, 0.0, 99.0),
  ('Energy Drink', 'drinks', '1 can (250ml)', 250.0, 110.0, 0.0, 28.0, 0.0, 0.0, 27.0, 50.0, 20.0, 2.0, 0.1, 0.0, 0.0, 89.0),
  ('Coconut Water', 'drinks', '1 cup (240g)', 240.0, 46.0, 1.7, 9.0, 0.5, 2.6, 6.0, 252.0, 600.0, 58.0, 0.7, 0.0, 5.0, 95.0),
  ('Milkshake', 'drinks', '1 cup (240g)', 240.0, 240.0, 8.0, 32.0, 9.0, 0.5, 28.0, 160.0, 380.0, 300.0, 0.2, 0.0, 0.0, 75.0),
  ('Fruit Smoothie', 'drinks', '1 cup (240g)', 240.0, 150.0, 3.0, 30.0, 2.0, 3.0, 22.0, 20.0, 350.0, 60.0, 0.5, 0.0, 40.0, 85.0),
  ('Almonds', 'nuts', '1/4 cup (28g)', 28.0, 164.0, 6.0, 6.0, 14.0, 3.5, 1.2, 0.0, 200.0, 76.0, 1.0, 0.0, 0.0, 4.0),
  ('Cashews', 'nuts', '1/4 cup (28g)', 28.0, 157.0, 5.0, 9.0, 12.0, 1.0, 1.7, 3.0, 160.0, 10.0, 1.9, 0.0, 0.0, 5.0),
  ('Peanuts', 'nuts', '1/4 cup (36g)', 36.0, 207.0, 9.4, 6.0, 18.0, 3.0, 2.0, 5.0, 220.0, 32.0, 1.3, 0.0, 0.0, 5.0),
  ('Walnuts', 'nuts', '1/4 cup (28g)', 28.0, 185.0, 4.3, 4.0, 18.0, 1.9, 0.7, 1.0, 125.0, 28.0, 0.8, 0.0, 0.0, 4.0),
  ('Pistachios', 'nuts', '1/4 cup (30g)', 30.0, 160.0, 6.0, 8.0, 13.0, 3.0, 2.0, 0.0, 300.0, 30.0, 1.2, 0.0, 0.0, 4.0),
  ('Hazelnuts', 'nuts', '1/4 cup (28g)', 28.0, 178.0, 4.2, 4.7, 17.0, 2.8, 1.2, 0.0, 193.0, 32.0, 1.3, 0.0, 0.0, 5.0),
  ('Macadamia Nuts', 'nuts', '1/4 cup (28g)', 28.0, 204.0, 2.2, 4.0, 21.0, 2.4, 1.3, 1.0, 104.0, 24.0, 1.0, 0.0, 0.0, 2.0),
  ('Pecans', 'nuts', '1/4 cup (28g)', 28.0, 196.0, 2.6, 4.0, 20.0, 2.7, 1.1, 0.0, 116.0, 20.0, 0.7, 0.0, 0.0, 4.0),
  ('Brazil Nuts', 'nuts', '1/4 cup (28g)', 28.0, 185.0, 4.0, 3.5, 19.0, 2.1, 0.7, 1.0, 187.0, 45.0, 0.7, 0.0, 0.0, 3.0),
  ('Peanut Butter', 'nuts', '2 tbsp (32g)', 32.0, 190.0, 8.0, 7.0, 16.0, 2.0, 3.0, 137.0, 190.0, 15.0, 0.6, 0.0, 0.0, 2.0),
  ('Almond Butter', 'nuts', '2 tbsp (32g)', 32.0, 196.0, 6.0, 6.0, 18.0, 3.3, 1.5, 73.0, 240.0, 110.0, 1.1, 0.0, 0.0, 2.0),
  ('Mixed Nuts', 'nuts', '1/4 cup (30g)', 30.0, 175.0, 5.0, 7.0, 15.0, 2.5, 1.5, 90.0, 180.0, 30.0, 1.2, 0.0, 0.0, 4.0),
  ('Chia Seeds', 'seeds', '2 tbsp (28g)', 28.0, 138.0, 4.7, 12.0, 8.7, 9.8, 0.0, 5.0, 115.0, 179.0, 2.2, 0.0, 0.0, 5.0),
  ('Flax Seeds', 'seeds', '2 tbsp (20g)', 20.0, 110.0, 3.8, 6.0, 8.7, 5.4, 0.3, 6.0, 160.0, 50.0, 1.2, 0.0, 0.0, 4.0),
  ('Sunflower Seeds', 'seeds', '1/4 cup (32g)', 32.0, 186.0, 6.3, 6.5, 16.0, 3.0, 0.8, 3.0, 240.0, 26.0, 1.6, 0.0, 0.0, 4.0),
  ('Pumpkin Seeds', 'seeds', '1/4 cup (30g)', 30.0, 168.0, 9.0, 3.0, 15.0, 2.0, 0.4, 5.0, 260.0, 16.0, 2.6, 0.0, 0.0, 4.0),
  ('Sesame Seeds', 'seeds', '2 tbsp (18g)', 18.0, 104.0, 3.2, 4.2, 9.0, 2.1, 0.1, 2.0, 84.0, 176.0, 2.6, 0.0, 0.0, 5.0),
  ('Poppy Seeds', 'seeds', '1 tbsp (9g)', 9.0, 46.0, 1.6, 2.5, 3.7, 1.7, 0.3, 2.0, 63.0, 127.0, 0.8, 0.0, 0.0, 6.0),
  ('Hemp Seeds', 'seeds', '3 tbsp (30g)', 30.0, 166.0, 9.5, 2.6, 15.0, 1.2, 0.5, 1.0, 360.0, 21.0, 2.4, 0.0, 0.0, 5.0),
  ('Quinoa (Cooked)', 'seeds', '1 cup (185g)', 185.0, 222.0, 8.0, 39.0, 3.6, 5.0, 1.6, 13.0, 318.0, 31.0, 2.8, 0.0, 0.0, 72.0),
  ('Tahini', 'seeds', '2 tbsp (30g)', 30.0, 178.0, 5.0, 6.0, 16.0, 2.8, 0.1, 33.0, 124.0, 154.0, 3.1, 0.0, 0.0, 3.0),
  ('Basil Seeds (Sabja)', 'seeds', '1 tbsp (10g)', 10.0, 40.0, 1.6, 6.0, 1.3, 4.0, 0.1, 1.0, 45.0, 45.0, 0.8, 0.0, 0.0, 5.0),
  ('Oats (Dry)', 'healthySnacks', '1/2 cup (40g)', 40.0, 154.0, 5.4, 27.0, 2.7, 4.0, 1.0, 2.0, 150.0, 21.0, 1.8, 0.0, 0.0, 9.0),
  ('Granola', 'healthySnacks', '1/2 cup (50g)', 50.0, 240.0, 5.0, 30.0, 12.0, 3.5, 12.0, 40.0, 150.0, 30.0, 1.5, 0.0, 0.0, 4.0),
  ('Muesli', 'healthySnacks', '1/2 cup (50g)', 50.0, 190.0, 5.0, 33.0, 4.0, 4.5, 8.0, 20.0, 220.0, 40.0, 1.8, 0.0, 0.0, 8.0),
  ('Air-Popped Popcorn', 'healthySnacks', '3 cups (24g)', 24.0, 93.0, 3.0, 18.6, 1.0, 3.5, 0.2, 2.0, 70.0, 2.0, 0.7, 0.0, 0.0, 8.0),
  ('Protein Bar', 'healthySnacks', '1 bar (60g)', 60.0, 210.0, 20.0, 22.0, 7.0, 2.0, 9.0, 200.0, 150.0, 100.0, 1.5, 0.0, 0.0, 8.0),
  ('Granola Bar', 'healthySnacks', '1 bar (25g)', 25.0, 110.0, 2.0, 17.0, 4.0, 1.2, 8.0, 60.0, 70.0, 10.0, 0.5, 0.0, 0.0, 6.0),
  ('Hummus', 'healthySnacks', '2 tbsp (30g)', 30.0, 78.0, 2.4, 4.5, 5.8, 1.5, 0.1, 120.0, 90.0, 12.0, 0.8, 0.0, 0.0, 60.0),
  ('Guacamole', 'healthySnacks', '2 tbsp (30g)', 30.0, 46.0, 0.6, 2.5, 4.0, 2.0, 0.2, 60.0, 150.0, 4.0, 0.2, 0.0, 0.0, 72.0),
  ('Trail Mix', 'healthySnacks', '1/4 cup (35g)', 35.0, 175.0, 5.0, 20.0, 10.0, 2.5, 12.0, 40.0, 180.0, 30.0, 1.0, 0.0, 0.0, 6.0),
  ('Dried Apricots', 'healthySnacks', '5 pieces (35g)', 35.0, 84.0, 1.2, 22.0, 0.2, 2.7, 18.0, 3.0, 420.0, 13.0, 0.9, 100.0, 0.0, 30.0),
  ('Raisins', 'healthySnacks', '1/4 cup (40g)', 40.0, 120.0, 1.3, 32.0, 0.2, 1.5, 24.0, 5.0, 320.0, 20.0, 0.8, 0.0, 0.0, 15.0),
  ('Veggie Sticks', 'healthySnacks', '1 cup (100g)', 100.0, 35.0, 1.5, 8.0, 0.3, 3.0, 3.0, 40.0, 250.0, 25.0, 0.5, 0.0, 30.0, 90.0),
  ('Fruit Salad', 'healthySnacks', '1 cup (200g)', 200.0, 100.0, 1.5, 25.0, 0.5, 4.0, 18.0, 5.0, 350.0, 30.0, 0.5, 0.0, 40.0, 85.0),
  ('Smoothie Bowl', 'healthySnacks', '1 bowl (300g)', 300.0, 250.0, 8.0, 45.0, 5.0, 6.0, 25.0, 60.0, 500.0, 100.0, 1.0, 0.0, 30.0, 75.0),
  ('Rice Crackers', 'healthySnacks', '10 pieces (30g)', 30.0, 120.0, 2.0, 24.0, 1.5, 1.0, 1.0, 200.0, 30.0, 5.0, 0.4, 0.0, 0.0, 5.0)on conflict (name) where user_id is null do nothing;

-- -----------------------------------------------------------------------------
-- 6. workout_templates (26 global routines)
-- -----------------------------------------------------------------------------
insert into public.workout_templates (
    category_id, name, description, difficulty, duration_minutes, calories_burn
)
select wc.id, v.name, v.description, v.difficulty, v.duration_minutes,
       v.calories_burn
from (values

  ('stretching', 'Morning Stretch Routine', 'Wake up your body with this gentle full-body mobility flow. Perfect for the start of the day.', 'beginner', 10, 40.0),
  ('full_body', 'Quick Home Warm-Up', 'A fast five-move warm-up to raise your heart rate and prepare the body for training.', 'beginner', 8, 60.0),
  ('full_body', 'Beginner Full Body', 'A simple, equipment-free routine that trains the whole body and builds a strong foundation.', 'beginner', 25, 150.0),
  ('full_body', 'Intermediate Full Body', 'A balanced strength and conditioning session covering every major muscle group.', 'intermediate', 35, 220.0),
  ('full_body', 'Advanced Full Body Blast', 'A demanding full-body circuit that pushes strength, power and endurance to the limit.', 'advanced', 40, 320.0),
  ('hiit', 'Home HIIT', 'High-intensity intervals that torch calories and boost your metabolism in just 20 minutes.', 'intermediate', 20, 200.0),
  ('cardio', 'Fat Burning Cardio', 'A steady calorie-torching session designed to melt fat and improve heart health.', 'intermediate', 25, 240.0),
  ('yoga', 'Yoga Flow', 'A calming yoga sequence that improves flexibility, balance and focus.', 'beginner', 20, 70.0),
  ('stretching', 'Stretch & Recover', 'A recovery-focused stretching routine to release tension and speed up muscle recovery.', 'beginner', 12, 40.0),
  ('core', 'Core Crusher', 'Fifteen minutes of focused abdominal work to build a strong, defined core.', 'intermediate', 15, 90.0),
  ('core', 'Advanced Core', 'A challenging core circuit for athletes who want serious abdominal strength.', 'advanced', 18, 100.0),
  ('upper_body', 'Upper Body Strength', 'A complete upper-body session targeting the chest, back, shoulders and arms.', 'intermediate', 30, 200.0),
  ('upper_body', 'Beginner Upper Body', 'An approachable upper-body routine that builds strength with beginner-friendly moves.', 'beginner', 20, 110.0),
  ('chest', 'Chest Builder', 'Push-ups and presses designed to build a bigger, stronger chest at home.', 'intermediate', 25, 160.0),
  ('back', 'Back Builder', 'A pulling-focused session that builds back width, thickness and posture.', 'intermediate', 30, 190.0),
  ('shoulder', 'Shoulder Sculpt', 'Presses and raises to sculpt strong, round shoulders.', 'intermediate', 25, 150.0),
  ('arms', 'Arm Blaster', 'Biceps, triceps and forearm work to build defined arms.', 'intermediate', 20, 120.0),
  ('legs', 'Leg Day', 'A complete lower-body session for strong, powerful legs.', 'intermediate', 35, 240.0),
  ('legs', 'Beginner Legs', 'A gentle introduction to lower-body training with foundational movements.', 'beginner', 20, 110.0),
  ('legs', 'Advanced Legs', 'A brutal lower-body circuit for experienced lifters chasing serious leg strength.', 'advanced', 40, 320.0),
  ('lower_body', 'Lower Body Focus', 'A beginner-friendly session focusing on the legs, glutes and core.', 'beginner', 25, 140.0),
  ('home_workout', 'Home No-Equipment', 'A complete bodyweight workout you can do anywhere with zero equipment.', 'beginner', 20, 130.0),
  ('gym_workout', 'Gym Strength', 'A dumbbell-based strength session built for the gym floor.', 'intermediate', 45, 300.0),
  ('fat_loss', 'Fat Loss Booster', 'A metabolic session combining strength and cardio to accelerate fat loss.', 'intermediate', 25, 260.0),
  ('muscle_gain', 'Muscle Builder', 'A hypertrophy-focused session designed to build lean muscle mass.', 'intermediate', 40, 280.0),
  ('hiit', 'Beginner HIIT', 'A gentle introduction to interval training with longer rests and manageable moves.', 'beginner', 15, 120.0)) as v(slug, name, description, difficulty, duration_minutes, calories_burn)
left join public.workout_categories wc on wc.slug = v.slug
on conflict (name) do nothing;

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

  ('Morning Stretch Routine', 'Cat-Cow', 0, 0, 60, 10, 0),
  ('Morning Stretch Routine', 'Child''s Pose', 0, 0, 60, 10, 1),
  ('Morning Stretch Routine', 'Standing Forward Fold', 0, 0, 60, 10, 2),
  ('Morning Stretch Routine', 'Downward Dog', 0, 0, 60, 10, 3),
  ('Morning Stretch Routine', 'Seated Hamstring Stretch', 0, 0, 60, 10, 4),
  ('Morning Stretch Routine', 'Hip Flexor Stretch', 0, 0, 60, 10, 5),
  ('Quick Home Warm-Up', 'Jumping Jacks', 0, 0, 40, 10, 0),
  ('Quick Home Warm-Up', 'Butt Kicks', 0, 0, 40, 10, 1),
  ('Quick Home Warm-Up', 'High Knees', 0, 0, 40, 10, 2),
  ('Quick Home Warm-Up', 'Skaters', 0, 0, 40, 10, 3),
  ('Quick Home Warm-Up', 'Plank', 0, 0, 30, 10, 4),
  ('Beginner Full Body', 'Squats', 3, 12, 0, 30, 0),
  ('Beginner Full Body', 'Push-Ups', 3, 10, 0, 30, 1),
  ('Beginner Full Body', 'Glute Bridges', 3, 15, 0, 20, 2),
  ('Beginner Full Body', 'Plank', 0, 0, 30, 20, 3),
  ('Beginner Full Body', 'Lunges', 3, 10, 0, 30, 4),
  ('Beginner Full Body', 'Crunches', 3, 15, 0, 20, 5),
  ('Intermediate Full Body', 'Squats', 4, 15, 0, 30, 0),
  ('Intermediate Full Body', 'Push-Ups', 4, 15, 0, 30, 1),
  ('Intermediate Full Body', 'Lunges', 3, 12, 0, 30, 2),
  ('Intermediate Full Body', 'Bicep Curls', 3, 12, 0, 20, 3),
  ('Intermediate Full Body', 'Plank', 0, 0, 45, 20, 4),
  ('Intermediate Full Body', 'Jumping Jacks', 0, 0, 45, 20, 5),
  ('Intermediate Full Body', 'Russian Twists', 3, 20, 0, 20, 6),
  ('Advanced Full Body Blast', 'Burpees', 3, 15, 0, 30, 0),
  ('Advanced Full Body Blast', 'Pull-Ups', 3, 10, 0, 30, 1),
  ('Advanced Full Body Blast', 'Jump Squats', 3, 15, 0, 30, 2),
  ('Advanced Full Body Blast', 'Chest Dips', 3, 12, 0, 30, 3),
  ('Advanced Full Body Blast', 'Mountain Climbers', 0, 0, 45, 20, 4),
  ('Advanced Full Body Blast', 'Dumbbell Shoulder Press', 3, 12, 0, 30, 5),
  ('Home HIIT', 'Jumping Jacks', 0, 0, 40, 20, 0),
  ('Home HIIT', 'High Knees', 0, 0, 40, 20, 1),
  ('Home HIIT', 'Burpees', 0, 0, 40, 20, 2),
  ('Home HIIT', 'Mountain Climbers', 0, 0, 40, 20, 3),
  ('Home HIIT', 'Squats', 0, 0, 40, 20, 4),
  ('Home HIIT', 'Plank', 0, 0, 40, 20, 5),
  ('Fat Burning Cardio', 'Jumping Jacks', 0, 0, 45, 15, 0),
  ('Fat Burning Cardio', 'High Knees', 0, 0, 45, 15, 1),
  ('Fat Burning Cardio', 'Skaters', 0, 0, 45, 15, 2),
  ('Fat Burning Cardio', 'Butt Kicks', 0, 0, 45, 15, 3),
  ('Fat Burning Cardio', 'Burpees', 0, 0, 45, 15, 4),
  ('Yoga Flow', 'Child''s Pose', 0, 0, 90, 10, 0),
  ('Yoga Flow', 'Cat-Cow', 0, 0, 60, 10, 1),
  ('Yoga Flow', 'Downward Dog', 0, 0, 60, 10, 2),
  ('Yoga Flow', 'Cobra Stretch', 0, 0, 60, 10, 3),
  ('Yoga Flow', 'Warrior II', 0, 0, 60, 10, 4),
  ('Yoga Flow', 'Pigeon Pose', 0, 0, 60, 10, 5),
  ('Yoga Flow', 'Bridge Pose', 0, 0, 60, 10, 6),
  ('Stretch & Recover', 'Child''s Pose', 0, 0, 60, 10, 0),
  ('Stretch & Recover', 'Standing Forward Fold', 0, 0, 60, 10, 1),
  ('Stretch & Recover', 'Seated Hamstring Stretch', 0, 0, 60, 10, 2),
  ('Stretch & Recover', 'Hip Flexor Stretch', 0, 0, 60, 10, 3),
  ('Stretch & Recover', 'Cobra Stretch', 0, 0, 60, 10, 4),
  ('Core Crusher', 'Plank', 0, 0, 40, 15, 0),
  ('Core Crusher', 'Crunches', 3, 20, 0, 15, 1),
  ('Core Crusher', 'Bicycle Crunches', 3, 20, 0, 15, 2),
  ('Core Crusher', 'Leg Raises', 3, 15, 0, 15, 3),
  ('Core Crusher', 'Russian Twists', 3, 20, 0, 15, 4),
  ('Core Crusher', 'Flutter Kicks', 0, 0, 40, 15, 5),
  ('Advanced Core', 'Plank', 0, 0, 60, 20, 0),
  ('Advanced Core', 'Side Plank', 0, 0, 40, 15, 1),
  ('Advanced Core', 'Hollow Body Hold', 0, 0, 40, 20, 2),
  ('Advanced Core', 'Russian Twists', 3, 30, 0, 15, 3),
  ('Advanced Core', 'Mountain Climbers', 0, 0, 45, 15, 4),
  ('Advanced Core', 'Leg Raises', 3, 20, 0, 15, 5),
  ('Upper Body Strength', 'Push-Ups', 4, 15, 0, 30, 0),
  ('Upper Body Strength', 'Pull-Ups', 3, 8, 0, 45, 1),
  ('Upper Body Strength', 'Bicep Curls', 3, 12, 0, 20, 2),
  ('Upper Body Strength', 'Tricep Dips', 3, 12, 0, 20, 3),
  ('Upper Body Strength', 'Lateral Raises', 3, 15, 0, 20, 4),
  ('Upper Body Strength', 'Dumbbell Shoulder Press', 3, 12, 0, 30, 5),
  ('Beginner Upper Body', 'Incline Push-Ups', 3, 12, 0, 30, 0),
  ('Beginner Upper Body', 'Prone Y Raise', 3, 12, 0, 20, 1),
  ('Beginner Upper Body', 'Bicep Curls', 3, 10, 0, 20, 2),
  ('Beginner Upper Body', 'Tricep Dips', 3, 8, 0, 30, 3),
  ('Beginner Upper Body', 'Lateral Raises', 3, 12, 0, 20, 4),
  ('Chest Builder', 'Push-Ups', 4, 15, 0, 30, 0),
  ('Chest Builder', 'Diamond Push-Ups', 3, 12, 0, 30, 1),
  ('Chest Builder', 'Wide Push-Ups', 3, 12, 0, 30, 2),
  ('Chest Builder', 'Dumbbell Bench Press', 3, 12, 0, 30, 3),
  ('Chest Builder', 'Dumbbell Fly', 3, 12, 0, 30, 4),
  ('Back Builder', 'Pull-Ups', 4, 8, 0, 45, 0),
  ('Back Builder', 'Bent-Over Dumbbell Row', 3, 12, 0, 30, 1),
  ('Back Builder', 'Renegade Row', 3, 10, 0, 30, 2),
  ('Back Builder', 'Reverse Fly', 3, 15, 0, 20, 3),
  ('Back Builder', 'Prone Y Raise', 3, 12, 0, 20, 4),
  ('Shoulder Sculpt', 'Dumbbell Shoulder Press', 4, 12, 0, 30, 0),
  ('Shoulder Sculpt', 'Lateral Raises', 3, 15, 0, 20, 1),
  ('Shoulder Sculpt', 'Front Raises', 3, 12, 0, 20, 2),
  ('Shoulder Sculpt', 'Arnold Press', 3, 12, 0, 30, 3),
  ('Shoulder Sculpt', 'Pike Push-Ups', 3, 10, 0, 30, 4),
  ('Arm Blaster', 'Bicep Curls', 4, 12, 0, 20, 0),
  ('Arm Blaster', 'Hammer Curls', 3, 12, 0, 20, 1),
  ('Arm Blaster', 'Tricep Dips', 4, 12, 0, 20, 2),
  ('Arm Blaster', 'Overhead Tricep Extension', 3, 12, 0, 20, 3),
  ('Arm Blaster', 'Skull Crushers', 3, 10, 0, 20, 4),
  ('Leg Day', 'Squats', 4, 15, 0, 30, 0),
  ('Leg Day', 'Lunges', 3, 12, 0, 30, 1),
  ('Leg Day', 'Step-Ups', 3, 12, 0, 30, 2),
  ('Leg Day', 'Romanian Deadlift', 3, 12, 0, 30, 3),
  ('Leg Day', 'Calf Raises', 4, 20, 0, 20, 4),
  ('Leg Day', 'Glute Bridges', 3, 15, 0, 20, 5),
  ('Beginner Legs', 'Squats', 3, 12, 0, 30, 0),
  ('Beginner Legs', 'Wall Sit', 0, 0, 30, 20, 1),
  ('Beginner Legs', 'Glute Bridges', 3, 15, 0, 20, 2),
  ('Beginner Legs', 'Calf Raises', 3, 15, 0, 20, 3),
  ('Beginner Legs', 'Lunges', 3, 10, 0, 30, 4),
  ('Advanced Legs', 'Jump Squats', 4, 15, 0, 30, 0),
  ('Advanced Legs', 'Bulgarian Split Squats', 3, 10, 0, 30, 1),
  ('Advanced Legs', 'Sumo Squats', 3, 15, 0, 30, 2),
  ('Advanced Legs', 'Romanian Deadlift', 4, 12, 0, 30, 3),
  ('Advanced Legs', 'Calf Raises', 4, 20, 0, 20, 4),
  ('Advanced Legs', 'Burpees', 3, 10, 0, 30, 5),
  ('Lower Body Focus', 'Squats', 3, 15, 0, 30, 0),
  ('Lower Body Focus', 'Lunges', 3, 10, 0, 30, 1),
  ('Lower Body Focus', 'Glute Bridges', 3, 15, 0, 20, 2),
  ('Lower Body Focus', 'Step-Ups', 3, 10, 0, 30, 3),
  ('Lower Body Focus', 'Calf Raises', 3, 15, 0, 20, 4),
  ('Home No-Equipment', 'Push-Ups', 3, 10, 0, 30, 0),
  ('Home No-Equipment', 'Squats', 3, 15, 0, 30, 1),
  ('Home No-Equipment', 'Plank', 0, 0, 30, 20, 2),
  ('Home No-Equipment', 'Lunges', 3, 10, 0, 30, 3),
  ('Home No-Equipment', 'Crunches', 3, 15, 0, 20, 4),
  ('Home No-Equipment', 'Jumping Jacks', 0, 0, 40, 20, 5),
  ('Gym Strength', 'Dumbbell Bench Press', 4, 12, 0, 45, 0),
  ('Gym Strength', 'Dumbbell Shoulder Press', 4, 12, 0, 45, 1),
  ('Gym Strength', 'Bent-Over Dumbbell Row', 4, 12, 0, 45, 2),
  ('Gym Strength', 'Bicep Curls', 3, 12, 0, 30, 3),
  ('Gym Strength', 'Dumbbell Fly', 3, 12, 0, 30, 4),
  ('Gym Strength', 'Romanian Deadlift', 4, 12, 0, 45, 5),
  ('Fat Loss Booster', 'Burpees', 0, 0, 45, 15, 0),
  ('Fat Loss Booster', 'Jump Squats', 0, 0, 45, 15, 1),
  ('Fat Loss Booster', 'Mountain Climbers', 0, 0, 45, 15, 2),
  ('Fat Loss Booster', 'Skaters', 0, 0, 45, 15, 3),
  ('Fat Loss Booster', 'High Knees', 0, 0, 45, 15, 4),
  ('Fat Loss Booster', 'Plank', 0, 0, 45, 15, 5),
  ('Muscle Builder', 'Dumbbell Bench Press', 4, 10, 0, 45, 0),
  ('Muscle Builder', 'Pull-Ups', 4, 8, 0, 45, 1),
  ('Muscle Builder', 'Squats', 4, 12, 0, 45, 2),
  ('Muscle Builder', 'Dumbbell Shoulder Press', 3, 12, 0, 45, 3),
  ('Muscle Builder', 'Bicep Curls', 3, 12, 0, 30, 4),
  ('Muscle Builder', 'Romanian Deadlift', 3, 12, 0, 45, 5),
  ('Beginner HIIT', 'Jumping Jacks', 0, 0, 30, 30, 0),
  ('Beginner HIIT', 'Butt Kicks', 0, 0, 30, 30, 1),
  ('Beginner HIIT', 'Squats', 0, 0, 30, 30, 2),
  ('Beginner HIIT', 'Crunches', 0, 0, 30, 30, 3),
  ('Beginner HIIT', 'Plank', 0, 0, 30, 30, 4)) as v(template_name, exercise_name, sets, reps, duration_seconds, rest_seconds,
       sort_order)
join public.workout_templates t on t.name = v.template_name
join public.exercises e on e.name = v.exercise_name and e.user_id is null
on conflict (template_id, exercise_id) do nothing;

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

