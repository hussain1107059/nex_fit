// Contracts for the server-authoritative master-catalog sync (PROMPT 16).
//
// Master data (foods, exercises, categories, goal/workout templates and the
// achievement / badge / challenge definition catalogs) is owned by the
// server and read-only for the app. The client is deliberately SELECT-only:
// it downloads catalogs, applies them idempotently to the local SQFlite
// tables and never pushes master rows back (master rows on the hybrid
// `food_item` / `exercise` / `fitness_goal` tables keep `user_id IS NULL`
// and are never written through the outbox DAOs).
//
// Versioning follows `public.master_data_versions`: the developer publishes a
// catalog, bumps its `data_version` and the client compares the stored
// version against the server's before deciding whether to download.

/// One transferable column of a master catalog: the cloud column name and the
/// local column it is written into (they differ for `image_url` -> `image` /
/// `image_path` and `gif_url` -> `gif_path`).
class MasterCatalogColumn {
  const MasterCatalogColumn(this.cloud, this.local);

  final String cloud;
  final String local;
}

/// Static definition of a single master catalog and how it maps onto a local
/// SQFlite table.
class MasterCatalogSpec {
  const MasterCatalogSpec({
    required this.catalog,
    required this.cloudTable,
    required this.localTable,
    required this.columns,
    required this.timestampColumns,
    this.booleanColumns = const <String>{},
    this.hybrid = false,
    this.naturalKeyCloud,
    this.naturalKeyLocal,
    this.cloudForeignKeys = const <String, String>{},
  });

  /// `master_data_versions.catalog` key.
  final String catalog;

  /// Cloud table name (e.g. `workout_categories`).
  final String cloudTable;

  /// Local SQFlite table name (e.g. `workout_category`).
  final String localTable;

  /// Transferable columns (cloud -> local). `uuid`, `deleted_at`,
  /// `row_version` and the `user_id` identity are handled by the applier and
  /// never listed here.
  final List<MasterCatalogColumn> columns;

  /// Cloud columns that are `timestamptz` and stored as epoch-ms locally.
  final Set<String> timestampColumns;

  /// Cloud boolean columns stored as 0/1 locally.
  final Set<String> booleanColumns;

  /// True when the local table is hybrid: master rows have `user_id IS NULL`
  /// and the download must only ever touch those rows (never user rows).
  final bool hybrid;

  /// Natural (stable, deduplicating) key used to adopt existing seeded rows in
  /// place. Null for uuid-identified tables (workout templates / template
  /// exercises).
  final String? naturalKeyCloud;
  final String? naturalKeyLocal;

  /// Cloud FK column -> LOCAL table whose `uuid` is the referenced row's cloud
  /// id. The applier resolves the uuid to the local integer id so local
  /// relationships stay integer-based (mirrors PROMPT 11).
  final Map<String, String> cloudForeignKeys;

  /// The cloud `updated_at` that this catalog's incremental pulls anchor on.
  String get updatedAtColumn => 'updated_at';
}

/// Registry of every catalog the master sync downloads, in dependency order
/// (parents before children so FK resolution always succeeds on a fresh
/// install).
class MasterCatalogRegistry {
  const MasterCatalogRegistry._();

  static const List<MasterCatalogSpec> catalogs = <MasterCatalogSpec>[
    // workout_categories -> workout_category (slug unique; existing seed rows
    // are adopted in place and stamped with the cloud uuid).
    MasterCatalogSpec(
      catalog: 'workout_categories',
      cloudTable: 'workout_categories',
      localTable: 'workout_category',
      naturalKeyCloud: 'slug',
      naturalKeyLocal: 'slug',
      columns: <MasterCatalogColumn>[
        MasterCatalogColumn('name', 'name'),
        MasterCatalogColumn('slug', 'slug'),
        MasterCatalogColumn('description', 'description'),
        MasterCatalogColumn('icon', 'icon'),
        MasterCatalogColumn('color', 'color'),
        MasterCatalogColumn('sort_order', 'sort_order'),
        MasterCatalogColumn('created_at', 'created_at'),
        MasterCatalogColumn('updated_at', 'updated_at'),
      ],
      timestampColumns: <String>{'created_at', 'updated_at'},
    ),
    // meal_categories -> meal_category (slug unique).
    MasterCatalogSpec(
      catalog: 'meal_categories',
      cloudTable: 'meal_categories',
      localTable: 'meal_category',
      naturalKeyCloud: 'slug',
      naturalKeyLocal: 'slug',
      columns: <MasterCatalogColumn>[
        MasterCatalogColumn('name', 'name'),
        MasterCatalogColumn('slug', 'slug'),
        MasterCatalogColumn('icon', 'icon'),
        MasterCatalogColumn('sort_order', 'sort_order'),
        MasterCatalogColumn('created_at', 'created_at'),
        MasterCatalogColumn('updated_at', 'updated_at'),
      ],
      timestampColumns: <String>{'created_at', 'updated_at'},
    ),
    // foods -> food_item (hybrid; only the user_id IS NULL master rows are
    // pulled). image_url maps back to the local image_path.
    MasterCatalogSpec(
      catalog: 'foods',
      cloudTable: 'foods',
      localTable: 'food_item',
      hybrid: true,
      naturalKeyCloud: 'name',
      naturalKeyLocal: 'name',
      columns: <MasterCatalogColumn>[
        MasterCatalogColumn('name', 'name'),
        MasterCatalogColumn('brand', 'brand'),
        MasterCatalogColumn('category', 'category'),
        MasterCatalogColumn('serving_size', 'serving_size'),
        MasterCatalogColumn('serving_grams', 'serving_grams'),
        MasterCatalogColumn('calories', 'calories'),
        MasterCatalogColumn('protein', 'protein'),
        MasterCatalogColumn('carbs', 'carbs'),
        MasterCatalogColumn('fat', 'fat'),
        MasterCatalogColumn('fiber', 'fiber'),
        MasterCatalogColumn('sugar', 'sugar'),
        MasterCatalogColumn('sodium', 'sodium'),
        MasterCatalogColumn('potassium', 'potassium'),
        MasterCatalogColumn('calcium', 'calcium'),
        MasterCatalogColumn('iron', 'iron'),
        MasterCatalogColumn('vitamin_a', 'vitamin_a'),
        MasterCatalogColumn('vitamin_c', 'vitamin_c'),
        MasterCatalogColumn('water_percentage', 'water_percentage'),
        MasterCatalogColumn('barcode', 'barcode'),
        MasterCatalogColumn('image_url', 'image_path'),
        MasterCatalogColumn('is_custom', 'is_custom'),
        MasterCatalogColumn('created_at', 'created_at'),
        MasterCatalogColumn('updated_at', 'updated_at'),
      ],
      timestampColumns: <String>{'created_at', 'updated_at'},
      booleanColumns: <String>{'is_custom'},
    ),
    // exercises -> exercise (hybrid; master rows only). image_url/gif_url map
    // back to the local image / gif_path columns.
    MasterCatalogSpec(
      catalog: 'exercises',
      cloudTable: 'exercises',
      localTable: 'exercise',
      hybrid: true,
      naturalKeyCloud: 'name',
      naturalKeyLocal: 'name',
      columns: <MasterCatalogColumn>[
        MasterCatalogColumn('name', 'name'),
        MasterCatalogColumn('scientific_name', 'scientific_name'),
        MasterCatalogColumn('description', 'description'),
        MasterCatalogColumn('instructions', 'instructions'),
        MasterCatalogColumn('body_part', 'body_part'),
        MasterCatalogColumn('secondary_muscle', 'secondary_muscle'),
        MasterCatalogColumn('equipment', 'equipment'),
        MasterCatalogColumn('difficulty', 'difficulty'),
        MasterCatalogColumn('category', 'category'),
        MasterCatalogColumn('image_url', 'image'),
        MasterCatalogColumn('gif_url', 'gif_path'),
        MasterCatalogColumn('calories_per_minute', 'calories_per_minute'),
        MasterCatalogColumn('estimated_calories', 'estimated_calories'),
        MasterCatalogColumn('duration_seconds', 'duration_seconds'),
        MasterCatalogColumn('sets', 'sets'),
        MasterCatalogColumn('reps', 'reps'),
        MasterCatalogColumn('rest_seconds', 'rest_seconds'),
        MasterCatalogColumn('tips', 'tips'),
        MasterCatalogColumn('common_mistakes', 'common_mistakes'),
        MasterCatalogColumn('safety_instructions', 'safety_instructions'),
        MasterCatalogColumn('is_custom', 'is_custom'),
        MasterCatalogColumn('created_at', 'created_at'),
        MasterCatalogColumn('updated_at', 'updated_at'),
      ],
      timestampColumns: <String>{'created_at', 'updated_at'},
      booleanColumns: <String>{'is_custom'},
    ),
    // goal_templates -> fitness_goal (hybrid; master rows keep user_id NULL
    // and are matched by goal_type).
    MasterCatalogSpec(
      catalog: 'goal_templates',
      cloudTable: 'goal_templates',
      localTable: 'fitness_goal',
      hybrid: true,
      naturalKeyCloud: 'goal_type',
      naturalKeyLocal: 'goal_type',
      columns: <MasterCatalogColumn>[
        MasterCatalogColumn('goal_type', 'goal_type'),
        MasterCatalogColumn('title', 'title'),
        MasterCatalogColumn('description', 'description'),
        MasterCatalogColumn('status', 'status'),
        MasterCatalogColumn('created_at', 'created_at'),
        MasterCatalogColumn('updated_at', 'updated_at'),
      ],
      timestampColumns: <String>{'created_at', 'updated_at'},
    ),
    // workout_templates -> workout_template (uuid-identified; category_id is
    // resolved from the cloud category uuid to the local int id).
    MasterCatalogSpec(
      catalog: 'workout_templates',
      cloudTable: 'workout_templates',
      localTable: 'workout_template',
      cloudForeignKeys: <String, String>{'category_id': 'workout_category'},
      columns: <MasterCatalogColumn>[
        MasterCatalogColumn('name', 'name'),
        MasterCatalogColumn('description', 'description'),
        MasterCatalogColumn('difficulty', 'difficulty'),
        MasterCatalogColumn('duration_minutes', 'duration_minutes'),
        MasterCatalogColumn('calories_burn', 'calories_burn'),
        MasterCatalogColumn('created_at', 'created_at'),
        MasterCatalogColumn('updated_at', 'updated_at'),
      ],
      timestampColumns: <String>{'created_at', 'updated_at'},
    ),
    // workout_template_exercises -> workout_template_exercise (uuid-identified;
    // template_id / exercise_id resolved to local int ids).
    MasterCatalogSpec(
      catalog: 'workout_template_exercises',
      cloudTable: 'workout_template_exercises',
      localTable: 'workout_template_exercise',
      cloudForeignKeys: <String, String>{
        'template_id': 'workout_template',
        'exercise_id': 'exercise',
      },
      columns: <MasterCatalogColumn>[
        MasterCatalogColumn('sets', 'sets'),
        MasterCatalogColumn('reps', 'reps'),
        MasterCatalogColumn('duration_seconds', 'duration_seconds'),
        MasterCatalogColumn('rest_seconds', 'rest_seconds'),
        MasterCatalogColumn('sort_order', 'sort_order'),
        MasterCatalogColumn('created_at', 'created_at'),
        MasterCatalogColumn('updated_at', 'updated_at'),
      ],
      timestampColumns: <String>{'created_at', 'updated_at'},
    ),
    // achievement_defs -> achievement_def
    MasterCatalogSpec(
      catalog: 'achievement_defs',
      cloudTable: 'achievement_defs',
      localTable: 'achievement_def',
      naturalKeyCloud: 'achievement_type',
      naturalKeyLocal: 'achievement_type',
      columns: <MasterCatalogColumn>[
        MasterCatalogColumn('achievement_type', 'achievement_type'),
        MasterCatalogColumn('name', 'name'),
        MasterCatalogColumn('description', 'description'),
        MasterCatalogColumn('icon', 'icon'),
        MasterCatalogColumn('xp_reward', 'xp_reward'),
        MasterCatalogColumn('sort_order', 'sort_order'),
        MasterCatalogColumn('created_at', 'created_at'),
        MasterCatalogColumn('updated_at', 'updated_at'),
      ],
      timestampColumns: <String>{'created_at', 'updated_at'},
    ),
    // badge_defs -> badge_def
    MasterCatalogSpec(
      catalog: 'badge_defs',
      cloudTable: 'badge_defs',
      localTable: 'badge_def',
      naturalKeyCloud: 'badge_type',
      naturalKeyLocal: 'badge_type',
      columns: <MasterCatalogColumn>[
        MasterCatalogColumn('badge_type', 'badge_type'),
        MasterCatalogColumn('badge_name', 'badge_name'),
        MasterCatalogColumn('icon', 'icon'),
        MasterCatalogColumn('description', 'description'),
        MasterCatalogColumn('level', 'level'),
        MasterCatalogColumn('target', 'target'),
        MasterCatalogColumn('sort_order', 'sort_order'),
        MasterCatalogColumn('created_at', 'created_at'),
        MasterCatalogColumn('updated_at', 'updated_at'),
      ],
      timestampColumns: <String>{'created_at', 'updated_at'},
    ),
    // challenge_defs -> challenge_def
    MasterCatalogSpec(
      catalog: 'challenge_defs',
      cloudTable: 'challenge_defs',
      localTable: 'challenge_def',
      naturalKeyCloud: 'challenge_type',
      naturalKeyLocal: 'challenge_type',
      columns: <MasterCatalogColumn>[
        MasterCatalogColumn('challenge_type', 'challenge_type'),
        MasterCatalogColumn('title', 'title'),
        MasterCatalogColumn('description', 'description'),
        MasterCatalogColumn('difficulty', 'difficulty'),
        MasterCatalogColumn('target', 'target'),
        MasterCatalogColumn('reward_xp', 'reward_xp'),
        MasterCatalogColumn('sort_order', 'sort_order'),
        MasterCatalogColumn('created_at', 'created_at'),
        MasterCatalogColumn('updated_at', 'updated_at'),
      ],
      timestampColumns: <String>{'created_at', 'updated_at'},
    ),
  ];

  static const List<MasterCatalogSpec> _byKey = catalogs;

  static MasterCatalogSpec? byCatalog(String catalog) {
    for (final MasterCatalogSpec spec in _byKey) {
      if (spec.catalog == catalog) return spec;
    }
    return null;
  }
}

/// A row of `public.master_data_versions`.
class MasterCatalogVersion {
  const MasterCatalogVersion({
    required this.catalog,
    this.dataVersion = 0,
    this.schemaVersion = 1,
    this.updatedAt,
  });

  final String catalog;
  final int dataVersion;
  final int schemaVersion;
  final DateTime? updatedAt;
}

/// One page of master rows fetched from a catalog table.
class MasterCatalogPage {
  const MasterCatalogPage({required this.rows, required this.hasMore});

  /// Raw cloud rows (column names = cloud names, timestamps as ISO-8601
  /// strings or DateTime).
  final List<Map<String, Object?>> rows;
  final bool hasMore;
}

/// Result of one catalog's sync run.
class MasterCatalogSyncResult {
  const MasterCatalogSyncResult({
    required this.catalog,
    this.skipped = false,
    this.succeeded = false,
    this.applied = 0,
    this.batches = 0,
    this.dataVersion = 0,
    this.error,
  });

  final String catalog;

  /// True when the server version equalled the stored version (or the catalog
  /// has no version row yet) and no download was attempted.
  final bool skipped;

  final bool succeeded;
  final int applied;
  final int batches;
  final int dataVersion;
  final String? error;

  bool get failed => !succeeded && !skipped;
}

/// Aggregate result of a full master-data sync run.
class MasterDataSyncResult {
  const MasterDataSyncResult({this.ran = true, this.catalogs = const <MasterCatalogSyncResult>[]});

  /// False when no transport was available and nothing was attempted.
  final bool ran;

  final List<MasterCatalogSyncResult> catalogs;

  bool get hasErrors => catalogs.any((MasterCatalogSyncResult r) => r.failed);
}

/// Server-backed transport for master catalogs (mirrors [SyncTransport] but
/// for the read-only, versioned master data flow).
abstract class MasterDataTransport {
  String get name;

  /// Whether the transport can serve requests right now.
  bool get isReady;

  /// Reads every `master_data_versions` cursor the server publishes.
  Future<List<MasterCatalogVersion>> getVersions();

  /// Fetches one page of [catalog] rows. When [since] is given only rows whose
  /// `updated_at` is on or after it are returned (high-watermark incremental
  /// pull). The transport must order rows deterministically and page via
  /// offset/limit.
  Future<MasterCatalogPage> pullRows(
    String catalog, {
    DateTime? since,
    int offset = 0,
    int limit = 100,
  });
}

/// Thrown by [MasterDataTransport] implementations on transient network /
/// server failures. The service treats it as retryable and keeps the last
/// good local catalog + version.
class MasterDataTransportException implements Exception {
  const MasterDataTransportException(this.message, {this.retryable = true});

  final String message;
  final bool retryable;

  @override
  String toString() => 'MasterDataTransportException($message)';
}
