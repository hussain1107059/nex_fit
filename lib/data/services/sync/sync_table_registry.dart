/// Maps a local SQFlite table to its cloud (Supabase) counterpart for the
/// push/pull transports.
///
/// Only the user-syncable tables whose DAOs currently record outbox events are
/// registered in this foundation phase. Unmapped entities are surfaced to the
/// engine as `unsupported_entity` rather than silently dropped.
class SyncTableMapping {
  const SyncTableMapping({
    required this.localTable,
    required this.cloudTable,
    required this.localToCloud,
    required this.timestampColumns,
    this.dateColumns = const <String>{},
    this.booleanColumns = const <String>{},
    this.localKeyColumn = 'id',
    this.cloudForeignKeys = const <String, String>{},
    this.cloudForeignKeyNames = const <String, String>{},
    this.cloudHasDeletedAt = true,
    this.alwaysUpsert = false,
  });

  /// Local table name, which is also the outbox `entity` value.
  final String localTable;

  /// Cloud table name.
  final String cloudTable;

  /// Local column -> cloud column. Cloud-only and local-only columns are
  /// deliberately omitted so both directions transfer a stable subset.
  final Map<String, String> localToCloud;

  /// Cloud columns stored as `timestamptz` that are epoch-ms locally.
  final Set<String> timestampColumns;

  /// Cloud columns typed `date` (no time component) that are epoch-ms locally.
  final Set<String> dateColumns;

  /// Cloud boolean columns that are 0/1 locally.
  final Set<String> booleanColumns;

  /// Local primary key column for row lookup: `id` for most tables,
  /// `user_id` for singletons (user_profile / app_settings).
  final String localKeyColumn;

  /// Local foreign-key column -> referenced LOCAL table whose `uuid` is the
  /// cloud identity of the referenced row. The push transport resolves the
  /// local integer id to the referenced row's `uuid` (and the applier resolves
  /// it back on pull), because local relationships stay integer-based while the
  /// cloud uses uuids (PROMPT 11). Columns listed here must NOT appear in
  /// [localToCloud].
  final Map<String, String> cloudForeignKeys;

  /// Cloud column name for each local foreign key in [cloudForeignKeys] where
  /// it differs from the local column name (defaults to the local name).
  /// Example: local `food_item_id` -> cloud `food_id`.
  final Map<String, String> cloudForeignKeyNames;

  /// Whether the cloud table carries a `deleted_at` tombstone column. The push
  /// transport sends `deleted_at` (null or ISO) so a locally resurrected row
  /// clears the cloud tombstone. `profiles` is the only table without one.
  final bool cloudHasDeletedAt;

  /// When true, every push uses the idempotent full-row upsert (keyed on the
  /// cloud `id`) regardless of `base_version`, skipping the optimistic
  /// `row_version` check. Intended for singletons (e.g. `user_settings`) where
  /// the whole row is the unit of truth: last-write-wins is correct, and a
  /// `row_version` drift would otherwise discard the user's latest preferences
  /// as a stale-write conflict instead of syncing them.
  final bool alwaysUpsert;

  /// The cloud `id` for a pushed row: its local `uuid` (singletons reuse the
  /// user id, which equals `uuid` after the v15 backfill).
  String cloudIdFor(Map<String, Object?> localRow) {
    return localRow['uuid'] as String;
  }
}

/// Registry of the local -> cloud table mappings used by the two-way sync
/// foundation. Extensible: add a new entry per table during the DAO migration
/// phase (see `docs/NEXFIT_DAO_SYNC_MIGRATION_PLAN.md`).
class SyncTableRegistry {
  const SyncTableRegistry._();

  /// The registered user-owned table mappings (the source of truth for which
  /// local tables participate in two-way sync).
  static List<SyncTableMapping> get mappings =>
      List<SyncTableMapping>.unmodifiable(_mappings);

  static const List<SyncTableMapping> _mappings = <SyncTableMapping>[
    // weight_log -> weight_logs
    SyncTableMapping(
      localTable: 'weight_log',
      cloudTable: 'weight_logs',
      localToCloud: <String, String>{
        'weight_kg': 'weight_kg',
        'note': 'note',
        'logged_at': 'logged_at',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'logged_at', 'created_at', 'updated_at'},
    ),
    // bmi_log -> bmi_logs
    SyncTableMapping(
      localTable: 'bmi_log',
      cloudTable: 'bmi_logs',
      localToCloud: <String, String>{
        'bmi': 'bmi',
        'weight_kg': 'weight_kg',
        'height_cm': 'height_cm',
        'category': 'category',
        'logged_at': 'logged_at',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'logged_at', 'created_at', 'updated_at'},
    ),
    // sleep_log -> sleep_logs. sleep_date is a cloud `date`; bedtime/wake_time
    // are full timestamps and stay on their own calendar day's local midnight.
    SyncTableMapping(
      localTable: 'sleep_log',
      cloudTable: 'sleep_logs',
      localToCloud: <String, String>{
        'sleep_date': 'sleep_date',
        'duration_minutes': 'duration_minutes',
        'bedtime': 'bedtime',
        'wake_time': 'wake_time',
        'quality': 'quality',
        'note': 'note',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'bedtime', 'wake_time', 'created_at', 'updated_at'},
      dateColumns: <String>{'sleep_date'},
    ),
    // step_log -> step_logs. step_date is a cloud `date`.
    SyncTableMapping(
      localTable: 'step_log',
      cloudTable: 'step_logs',
      localToCloud: <String, String>{
        'step_date': 'step_date',
        'steps': 'steps',
        'distance_km': 'distance_km',
        'calories_burned': 'calories_burned',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'created_at', 'updated_at'},
      dateColumns: <String>{'step_date'},
    ),
    // water_log -> water_logs
    SyncTableMapping(
      localTable: 'water_log',
      cloudTable: 'water_logs',
      localToCloud: <String, String>{
        'amount_ml': 'amount_ml',
        'logged_at': 'logged_at',
        'note': 'note',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'logged_at', 'created_at', 'updated_at'},
    ),
    // body_measurement -> body_measurements
    SyncTableMapping(
      localTable: 'body_measurement',
      cloudTable: 'body_measurements',
      localToCloud: <String, String>{
        'chest_cm': 'chest_cm',
        'waist_cm': 'waist_cm',
        'hip_cm': 'hip_cm',
        'arm_cm': 'arm_cm',
        'thigh_cm': 'thigh_cm',
        'neck_cm': 'neck_cm',
        'shoulder_cm': 'shoulder_cm',
        'left_arm_cm': 'left_arm_cm',
        'right_arm_cm': 'right_arm_cm',
        'left_thigh_cm': 'left_thigh_cm',
        'right_thigh_cm': 'right_thigh_cm',
        'left_calf_cm': 'left_calf_cm',
        'right_calf_cm': 'right_calf_cm',
        'note': 'note',
        'measured_at': 'measured_at',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'measured_at', 'created_at', 'updated_at'},
    ),
    // reminder -> reminders. `start_date` / `end_date` are cloud `date`
    // columns; `days_of_week` and `times` round-trip as plain text on both
    // sides. The schedule + sound columns are part of the user-owned reminder.
    SyncTableMapping(
      localTable: 'reminder',
      cloudTable: 'reminders',
      localToCloud: <String, String>{
        'title': 'title',
        'body': 'body',
        'reminder_type': 'reminder_type',
        'time': 'time',
        'days_of_week': 'days_of_week',
        'schedule_type': 'schedule_type',
        'times': 'times',
        'start_date': 'start_date',
        'end_date': 'end_date',
        'month_day': 'month_day',
        'icon': 'icon',
        'color_value': 'color_value',
        'sound_enabled': 'sound_enabled',
        'vibration_enabled': 'vibration_enabled',
        'silent_mode': 'silent_mode',
        'show_action_buttons': 'show_action_buttons',
        'related_screen': 'related_screen',
        'is_enabled': 'is_enabled',
        'last_triggered_at': 'last_triggered_at',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'last_triggered_at', 'created_at', 'updated_at'},
      dateColumns: <String>{'start_date', 'end_date'},
      booleanColumns: <String>{
        'is_enabled',
        'sound_enabled',
        'vibration_enabled',
        'silent_mode',
        'show_action_buttons',
      },
    ),
    // reminder_history -> reminder_history (occurrence events; reminder_id is
    // a local integer FK resolved to the reminder's cloud uuid)
    SyncTableMapping(
      localTable: 'reminder_history',
      cloudTable: 'reminder_history',
      localToCloud: <String, String>{
        'status': 'status',
        'scheduled_for': 'scheduled_for',
        'acted_at': 'acted_at',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'scheduled_for', 'acted_at', 'created_at', 'updated_at'},
      cloudForeignKeys: <String, String>{'reminder_id': 'reminder'},
    ),
    // reward -> user_rewards (claim records; all columns are user-owned, no
    // master-definition link on either side)
    SyncTableMapping(
      localTable: 'reward',
      cloudTable: 'user_rewards',
      localToCloud: <String, String>{
        'type': 'type',
        'title': 'title',
        'amount': 'amount',
        'icon': 'icon',
        'is_claimed': 'is_claimed',
        'claimed_at': 'claimed_at',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'claimed_at', 'created_at', 'updated_at'},
      booleanColumns: <String>{'is_claimed'},
    ),
    // xp_history -> xp_history (append-only XP ledger). `total_xp` is a
    // derived running total (recomputable as SUM(xp)) and `metadata` is a
    // cloud jsonb column that the text transport cannot round-trip safely, so
    // both are deliberately excluded from the sync mapping (PROMPT 14).
    SyncTableMapping(
      localTable: 'xp_history',
      cloudTable: 'xp_history',
      localToCloud: <String, String>{
        'source': 'source',
        'reason': 'reason',
        'xp': 'xp',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'created_at', 'updated_at'},
    ),
    // workout_history -> workout_history
    SyncTableMapping(
      localTable: 'workout_history',
      cloudTable: 'workout_history',
      localToCloud: <String, String>{
        'started_at': 'started_at',
        'ended_at': 'ended_at',
        'duration_minutes': 'duration_minutes',
        'calories_burn': 'calories_burn',
        'notes': 'notes',
        'is_completed': 'is_completed',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'started_at', 'ended_at', 'created_at', 'updated_at'},
      booleanColumns: <String>{'is_completed'},
      cloudForeignKeys: <String, String>{'workout_id': 'workout'},
    ),
    // user_profile -> profiles (singleton; no deleted_at on cloud)
    SyncTableMapping(
      localTable: 'user_profile',
      cloudTable: 'profiles',
      localKeyColumn: 'user_id',
      cloudHasDeletedAt: false,
      localToCloud: <String, String>{
        'height_cm': 'height_cm',
        'weight_kg': 'weight_kg',
        'gender': 'gender',
        'birth_date': 'birth_date',
        'activity_level': 'activity_level',
        'timezone': 'timezone',
        'target_calories': 'target_calories',
        'target_protein': 'target_protein',
        'target_carbs': 'target_carbs',
        'target_fat': 'target_fat',
        'target_water_ml': 'target_water_ml',
        'target_steps': 'target_steps',
        'target_weight_kg': 'target_weight_kg',
        'fitness_goal': 'fitness_goal',
        'country': 'country',
        'language': 'language',
        'photo_path': 'avatar_url',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'birth_date', 'created_at', 'updated_at'},
      dateColumns: <String>{'birth_date'},
    ),
    // app_settings -> user_settings (singleton). `theme_mode` is the
    // authoritative local column (v11, NOT NULL); the legacy nullable `theme`
    // is never written and must not be pushed. `locale` is stored in
    // SharedPreferences (never in the local table) and the local table has no
    // `created_at`, so both are omitted and the server's NOT NULL defaults
    // apply instead of the app pushing explicit nulls.
    SyncTableMapping(
      localTable: 'app_settings',
      cloudTable: 'user_settings',
      localKeyColumn: 'user_id',
      alwaysUpsert: true,
      localToCloud: <String, String>{
        'theme_mode': 'theme_mode',
        'units': 'units',
        'week_start': 'week_start',
        'daily_calorie_target': 'daily_calorie_target',
        'daily_water_target_ml': 'daily_water_target_ml',
        'daily_step_target': 'daily_step_target',
        'protein_goal': 'protein_goal',
        'carbs_goal': 'carbs_goal',
        'fat_goal': 'fat_goal',
        'notifications_enabled': 'notifications_enabled',
        'reminder_enabled': 'reminder_enabled',
        'workout_reminder_enabled': 'workout_reminder_enabled',
        'meal_reminder_enabled': 'meal_reminder_enabled',
        'water_reminder_enabled': 'water_reminder_enabled',
        'weight_reminder_enabled': 'weight_reminder_enabled',
        'sleep_reminder_enabled': 'sleep_reminder_enabled',
        'challenge_reminder_enabled': 'challenge_reminder_enabled',
        'achievement_reminder_enabled': 'achievement_reminder_enabled',
        'default_rest_time_seconds': 'default_rest_time_seconds',
        'auto_start_timer': 'auto_start_timer',
        'countdown_voice': 'countdown_voice',
        'exercise_animation': 'exercise_animation',
        'auto_next_exercise': 'auto_next_exercise',
        'data_sync_enabled': 'data_sync_enabled',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'created_at', 'updated_at'},
      booleanColumns: <String>{
        'notifications_enabled',
        'reminder_enabled',
        'workout_reminder_enabled',
        'meal_reminder_enabled',
        'water_reminder_enabled',
        'weight_reminder_enabled',
        'sleep_reminder_enabled',
        'challenge_reminder_enabled',
        'achievement_reminder_enabled',
        'auto_start_timer',
        'countdown_voice',
        'exercise_animation',
        'auto_next_exercise',
        'data_sync_enabled',
      },
    ),
    // fitness_goal -> fitness_goals
    SyncTableMapping(
      localTable: 'fitness_goal',
      cloudTable: 'fitness_goals',
      localToCloud: <String, String>{
        'title': 'title',
        'description': 'description',
        'goal_type': 'goal_type',
        'target_value': 'target_value',
        'current_value': 'current_value',
        'start_date': 'start_date',
        'target_date': 'target_date',
        'status': 'status',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'start_date', 'target_date', 'created_at', 'updated_at'},
      dateColumns: <String>{'start_date', 'target_date'},
    ),
    // workout -> workouts (category_id is a local integer id referencing the
    // master catalog, which is not uuid-synced, so it is intentionally omitted)
    SyncTableMapping(
      localTable: 'workout',
      cloudTable: 'workouts',
      localToCloud: <String, String>{
        'name': 'name',
        'description': 'description',
        'difficulty': 'difficulty',
        'duration_minutes': 'duration_minutes',
        'calories_burn': 'calories_burn',
        'image': 'image_url',
        'is_favorite': 'is_favorite',
        'is_custom': 'is_custom',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'created_at', 'updated_at'},
      booleanColumns: <String>{'is_favorite', 'is_custom'},
    ),
    // workout_exercise -> workout_exercises (workout_id / exercise_id are
    // local integer refs; the uuids are resolved through cloudForeignKeys)
    SyncTableMapping(
      localTable: 'workout_exercise',
      cloudTable: 'workout_exercises',
      localToCloud: <String, String>{
        'sets': 'sets',
        'reps': 'reps',
        'duration_seconds': 'duration_seconds',
        'rest_seconds': 'rest_seconds',
        'sort_order': 'sort_order',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'created_at', 'updated_at'},
      cloudForeignKeys: <String, String>{
        'workout_id': 'workout',
        'exercise_id': 'exercise',
      },
    ),
    // exercise_history -> exercise_history (workout_history_id / exercise_id
    // are local integer refs resolved through cloudForeignKeys)
    SyncTableMapping(
      localTable: 'exercise_history',
      cloudTable: 'exercise_history',
      localToCloud: <String, String>{
        'sets': 'sets',
        'reps': 'reps',
        'weight_kg': 'weight_kg',
        'duration_seconds': 'duration_seconds',
        'completed_at': 'completed_at',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'completed_at', 'created_at', 'updated_at'},
      cloudForeignKeys: <String, String>{
        'workout_history_id': 'workout_history',
        'exercise_id': 'exercise',
      },
    ),
    // exercise_favorite -> exercise_favorites (composite-PK join row keyed by
    // its uuid; exercise_id resolved through cloudForeignKeys)
    SyncTableMapping(
      localTable: 'exercise_favorite',
      cloudTable: 'exercise_favorites',
      localKeyColumn: 'uuid',
      localToCloud: <String, String>{
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'created_at', 'updated_at'},
      cloudForeignKeys: <String, String>{'exercise_id': 'exercise'},
    ),
    // food_log -> food_logs. food_item_id is the local FK for cloud `food_id`;
    // meal_id resolves to meals. meal_type_id (-> meal_categories) is omitted
    // because the local meal_category catalog is master data without uuids.
    SyncTableMapping(
      localTable: 'food_log',
      cloudTable: 'food_logs',
      localToCloud: <String, String>{
        'quantity': 'quantity',
        'serving_size': 'serving_size',
        'calories': 'calories',
        'protein': 'protein',
        'carbs': 'carbs',
        'fat': 'fat',
        'fiber': 'fiber',
        'sugar': 'sugar',
        'logged_at': 'logged_at',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'logged_at', 'created_at', 'updated_at'},
      cloudForeignKeys: <String, String>{
        'food_item_id': 'food_item',
        'meal_id': 'meal',
      },
      cloudForeignKeyNames: <String, String>{
        'food_item_id': 'food_id',
      },
    ),
    // food_favorite -> food_favorites (composite-PK join row keyed by uuid)
    SyncTableMapping(
      localTable: 'food_favorite',
      cloudTable: 'food_favorites',
      localKeyColumn: 'uuid',
      localToCloud: <String, String>{
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'created_at', 'updated_at'},
      cloudForeignKeys: <String, String>{'food_item_id': 'food_item'},
      cloudForeignKeyNames: <String, String>{
        'food_item_id': 'food_id',
      },
    ),
    // meal -> meals (category_id references the master meal_category catalog
    // which is not uuid-synced, so it is intentionally omitted, like
    // workout.category_id)
    SyncTableMapping(
      localTable: 'meal',
      cloudTable: 'meals',
      localToCloud: <String, String>{
        'name': 'name',
        'description': 'description',
        'calories': 'calories',
        'protein': 'protein',
        'carbs': 'carbs',
        'fat': 'fat',
        'image': 'image_url',
        'is_favorite': 'is_favorite',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'created_at', 'updated_at'},
      booleanColumns: <String>{'is_favorite'},
    ),
    // meal_item -> meal_items (meal_id / food_item_id resolved through
    // cloudForeignKeys; the cloud food column is `food_id`)
    SyncTableMapping(
      localTable: 'meal_item',
      cloudTable: 'meal_items',
      localToCloud: <String, String>{
        'quantity': 'quantity',
        'sort_order': 'sort_order',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'created_at', 'updated_at'},
      cloudForeignKeys: <String, String>{
        'meal_id': 'meal',
        'food_item_id': 'food_item',
      },
      cloudForeignKeyNames: <String, String>{
        'food_item_id': 'food_id',
      },
    ),
    // exercise -> exercises (hybrid table: master rows have user_id IS NULL
    // and stay local-only catalog; only the user's custom rows are synced).
    // image maps to the cloud image_url and gif_path to gif_url; is_custom
    // round-trips as a boolean. workout_exercise / exercise_history /
    // exercise_favorite already resolve their exercise_id to this uuid.
    SyncTableMapping(
      localTable: 'exercise',
      cloudTable: 'exercises',
      localToCloud: <String, String>{
        'name': 'name',
        'scientific_name': 'scientific_name',
        'description': 'description',
        'instructions': 'instructions',
        'body_part': 'body_part',
        'secondary_muscle': 'secondary_muscle',
        'equipment': 'equipment',
        'difficulty': 'difficulty',
        'category': 'category',
        'image': 'image_url',
        'gif_path': 'gif_url',
        'calories_per_minute': 'calories_per_minute',
        'estimated_calories': 'estimated_calories',
        'duration_seconds': 'duration_seconds',
        'sets': 'sets',
        'reps': 'reps',
        'rest_seconds': 'rest_seconds',
        'tips': 'tips',
        'common_mistakes': 'common_mistakes',
        'safety_instructions': 'safety_instructions',
        'is_custom': 'is_custom',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'created_at', 'updated_at'},
      booleanColumns: <String>{'is_custom'},
    ),
    // food_item -> foods (hybrid table: master rows have user_id IS NULL and
    // stay local-only catalog; only the user's custom rows are synced — the
    // DAO emits outbox events exclusively for rows with a non-null user_id).
    // image_path maps to the cloud image_url and is_custom round-trips as a
    // boolean. The cloud id is the local uuid, which food_log / food_favorite
    // / meal_item already resolve to via their food_id foreign key.
    SyncTableMapping(
      localTable: 'food_item',
      cloudTable: 'foods',
      localToCloud: <String, String>{
        'name': 'name',
        'brand': 'brand',
        'category': 'category',
        'serving_size': 'serving_size',
        'serving_grams': 'serving_grams',
        'calories': 'calories',
        'protein': 'protein',
        'carbs': 'carbs',
        'fat': 'fat',
        'fiber': 'fiber',
        'sugar': 'sugar',
        'sodium': 'sodium',
        'potassium': 'potassium',
        'calcium': 'calcium',
        'iron': 'iron',
        'vitamin_a': 'vitamin_a',
        'vitamin_c': 'vitamin_c',
        'water_percentage': 'water_percentage',
        'barcode': 'barcode',
        'image_path': 'image_url',
        'is_custom': 'is_custom',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'created_at', 'updated_at'},
      booleanColumns: <String>{'is_custom'},
    ),
    // user_level -> user_levels (singleton per user, keyed by user_id like
    // user_profile / app_settings). The row uuid equals the user id, so the
    // pushed cloud id is the user id. All four level/XP columns are stored user
    // state owned by the level system; unlike xp_history.total_xp (which is
    // duplicated per ledger row) they are the singleton's canonical counters.
    SyncTableMapping(
      localTable: 'user_level',
      cloudTable: 'user_levels',
      localKeyColumn: 'user_id',
      localToCloud: <String, String>{
        'level': 'level',
        'current_xp': 'current_xp',
        'required_xp': 'required_xp',
        'total_xp': 'total_xp',
        'created_at': 'created_at',
        'updated_at': 'updated_at',
      },
      timestampColumns: <String>{'created_at', 'updated_at'},
    ),
  ];

  /// The mapping for [localTable] (outbox `entity` name), or null.
  static SyncTableMapping? byLocalTable(String localTable) {
    for (final SyncTableMapping mapping in _mappings) {
      if (mapping.localTable == localTable) return mapping;
    }
    return null;
  }

  /// The mapping for [cloudTable] (pulled `sync_changes.table_name`), or null.
  static SyncTableMapping? byCloudTable(String cloudTable) {
    for (final SyncTableMapping mapping in _mappings) {
      if (mapping.cloudTable == cloudTable) return mapping;
    }
    return null;
  }
}