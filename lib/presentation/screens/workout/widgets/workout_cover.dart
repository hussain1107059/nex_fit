import 'package:flutter/material.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radius.dart';

/// Resolves a Material icon name (from the category catalog) into [IconData].
IconData categoryIconFor(
  String? iconName, {
  IconData fallback = Icons.fitness_center_rounded,
}) {
  if (iconName == null || iconName.isEmpty) return fallback;
  return switch (iconName) {
    'home' || 'home_workout' => Icons.home_rounded,
    'gym' || 'gym_workout' || 'fitness_center' => Icons.fitness_center_rounded,
    'directions_run' || 'running' => Icons.directions_run_rounded,
    'self_improvement' || 'yoga' => Icons.self_improvement_rounded,
    'accessibility_new' || 'full_body' => Icons.accessibility_new_rounded,
    'sports_gymnastics' || 'upper_body' => Icons.sports_gymnastics_rounded,
    'health_and_safety' => Icons.health_and_safety_rounded,
    'sports_martial_arts' => Icons.sports_martial_arts_rounded,
    'airline_seat_flat' ||
    'stretching' => Icons.airline_seat_legroom_extra_rounded,
    'bolt' || 'hiit' => Icons.bolt_rounded,
    'local_fire_department' || 'cardio' => Icons.local_fire_department_rounded,
    'whatshot' || 'fat_loss' => Icons.whatshot_rounded,
    'sports_kabaddi' || 'strength' || 'muscle_gain' => Icons
        .sports_kabaddi_rounded,
    'stairs' || 'legs' || 'lower_body' => Icons.stairs_rounded,
    'rowing' || 'back' => Icons.rowing_rounded,
    'sports_handball' || 'shoulder' => Icons.sports_handball_rounded,
    'shield' || 'chest' => Icons.shield_rounded,
    'donut_large' || 'core' => Icons.donut_large_rounded,
    'front_hand' || 'arms' => Icons.front_hand_rounded,
    'school' || 'beginner' => Icons.school_rounded,
    'military_tech' || 'intermediate' => Icons.military_tech_rounded,
    'emoji_events' || 'advanced' => Icons.emoji_events_rounded,
    'sports' => Icons.sports_rounded,
    'scale' || 'weight' => Icons.scale_rounded,
    'fitness_center_rounded' => Icons.fitness_center_rounded,
    _ => fallback,
  };
}

/// Infers an icon from a workout/exercise name by keyword matching
/// (English + Bangla keywords). Returns null when nothing matches so callers
/// can fall back to the category icon.
///
/// Order matters: specific intents (yoga, stretch, HIIT...) are checked before
/// broad ones (strength, gym, home) and body parts before equipment words.
IconData? workoutIconFromName(String? rawName) {
  final String n = (rawName ?? '').toLowerCase();
  if (n.trim().isEmpty) return null;
  bool has(List<String> keys) => keys.any(n.contains);

  // Mind & body disciplines.
  if (has(<String>['yoga', 'যোগ'])) return Icons.self_improvement_rounded;
  if (has(<String>['pilates'])) return Icons.self_improvement_rounded;
  if (has(<String>['meditat', 'mindful', 'ধ্যান'])) return Icons.spa_rounded;

  // Flexibility / warm-up / recovery.
  if (has(<String>[
    'stretch',
    'warm',
    'cool down',
    'cooldown',
    'mobility',
    'flexib',
    'recover',
    'স্ট্রেচ',
  ])) {
    return Icons.airline_seat_legroom_extra_rounded;
  }

  // Metabolic conditioning.
  if (has(<String>['hiit', 'interval', 'tabata', 'circuit', 'এইচআইআইটি'])) {
    return Icons.bolt_rounded;
  }
  if (has(<String>['cardio', 'aerobic', 'fat', 'burn', 'কার্ডিও', 'মোটা'])) {
    return Icons.local_fire_department_rounded;
  }

  // Locomotion & sport.
  if (has(<String>['run', 'jog', 'sprint', 'দৌড়'])) {
    return Icons.directions_run_rounded;
  }
  if (has(<String>['walk', 'হাঁটা'])) return Icons.directions_walk_rounded;
  if (has(<String>['cycl', 'bike', 'spin', 'সাইকেল'])) {
    return Icons.directions_bike_rounded;
  }
  if (has(<String>['swim', 'pool', 'সাঁতার'])) return Icons.pool_rounded;
  if (has(<String>['hik', 'trek'])) return Icons.hiking_rounded;
  if (has(<String>['row'])) return Icons.rowing_rounded;

  // Combat / dance.
  if (has(<String>[
    'box',
    'mma',
    'kick',
    'karate',
    'martial',
    'taekwondo',
    'বক্সিং',
  ])) {
    return Icons.sports_mma_rounded;
  }
  if (has(<String>['dance', 'zumba', 'নাচ', 'জুম্বা'])) {
    return Icons.emoji_people_rounded;
  }

  // Body-part focus.
  if (has(<String>[
    'core',
    'abs',
    'crunch',
    'plank',
    'twist',
    'কোর',
    'পেট',
  ])) {
    return Icons.donut_large_rounded;
  }
  if (has(<String>[
    'leg',
    'squat',
    'lunge',
    'glute',
    'calf',
    'quad',
    'hamstring',
    'lower body',
    'পায়ের',
  ])) {
    return Icons.stairs_rounded;
  }
  if (has(<String>['chest', 'push', 'bench', 'pec', 'বুক'])) {
    return Icons.shield_rounded;
  }
  if (has(<String>['shoulder', 'delt'])) return Icons.sports_handball_rounded;
  if (has(<String>['arm', 'bicep', 'tricep', 'forearm'])) {
    return Icons.front_hand_rounded;
  }
  if (has(<String>['back', 'pull', 'lat ', 'পিঠ'])) return Icons.rowing_rounded;
  if (has(<String>['upper body'])) return Icons.sports_gymnastics_rounded;
  if (has(<String>['full body', 'full-body', 'ফুল বডি'])) {
    return Icons.accessibility_new_rounded;
  }

  // Strength & equipment.
  if (has(<String>[
    'strength',
    'muscle',
    'build',
    'power',
    'bodybuild',
    'gain',
    'শক্তি',
  ])) {
    return Icons.sports_kabaddi_rounded;
  }
  if (has(<String>[
    'gym',
    'lift',
    'dumbbell',
    'barbell',
    'kettlebell',
    'weight train',
  ])) {
    return Icons.fitness_center_rounded;
  }
  if (has(<String>['home', 'no equip', 'বাড়ি'])) return Icons.home_rounded;

  return null;
}

/// Best icon for a named workout: name keywords first, then its category
/// icon, then the generic dumbbell fallback.
IconData workoutIconFor(String? name, String? categoryIcon) =>
    workoutIconFromName(name) ??
    categoryIconFor(categoryIcon);

/// Palette used to give uncategorized workouts a stable, distinct cover color.
const List<int> _coverPalette = <int>[
  0xFF7C4DFF, // deep purple
  0xFF1E88E5, // blue
  0xFF00897B, // teal
  0xFF43A047, // green
  0xFFF4511E, // deep orange
  0xFFD81B60, // pink
  0xFF5C6BC0, // indigo
  0xFFFB8C00, // orange
  0xFF6D4C41, // brown
  0xFF039BE5, // light blue
];

/// Deterministic cover color derived from a workout/exercise name, used when
/// no category color exists so tiles stay visually distinct.
int workoutColorValueForName(String? name) {
  final String n = name ?? '';
  int hash = 0;
  for (final int unit in n.codeUnits) {
    hash = (hash * 31 + unit) & 0x7FFFFFFF;
  }
  return _coverPalette[hash % _coverPalette.length];
}

/// Gradient cover used by workout and category tiles when no image exists.
class WorkoutCover extends StatelessWidget {
  const WorkoutCover({
    super.key,
    this.colorValue,
    this.label,
    this.icon,
    this.width = double.infinity,
    this.height = 120,
    this.borderRadius,
  });

  final int? colorValue;
  final String? label;
  final IconData? icon;
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final Color base = colorValue != null
        ? Color(colorValue!)
        : context.colorScheme.primary;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? AppRadius.mdRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            base.withValues(alpha: 0.9),
            base.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: height * 0.4,
          color: Color.alphaBlend(
            base.withValues(alpha: 0.72),
            context.colorScheme.surface,
          ).computeLuminance() > 0.5
              ? Colors.black87.withValues(alpha: 0.9)
              : Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
