import 'package:sqflite/sqflite.dart' show Database, Transaction;

import '../../../core/security/uuid_generator.dart';
import '../../datasources/local/app_database.dart';
import '../../datasources/local/syncable_dao.dart';
import 'sync_table_registry.dart';

/// Per-table ownership classification for a single user-owned table.
class LocalTableOwnership {
  const LocalTableOwnership({
    required this.table,
    this.currentUser = 0,
    this.otherAccounts = 0,
    this.orphans = 0,
  });

  final String table;

  /// Rows owned by the authenticated user.
  final int currentUser;

  /// Rows owned by a different account (never auto-adopted, never uploaded).
  final int otherAccounts;

  /// Rows with no owner (NULL / empty `user_id`), eligible for explicit adoption.
  final int orphans;

  bool get isEmpty => currentUser == 0 && otherAccounts == 0 && orphans == 0;
}

/// Result of classifying every user-owned row against the authenticated user.
///
/// Used to decide how pre-existing local data is handled on first sync: it is
/// never deleted, never silently uploaded for another account, and orphaned
/// rows are only adopted after explicit user opt-in.
class OwnershipAnalysis {
  const OwnershipAnalysis({
    required this.byTable,
    required this.previousAccountIds,
    required this.hasCurrentUserData,
  });

  /// Per-table classification, only tables with at least one row included.
  final Map<String, LocalTableOwnership> byTable;

  /// Distinct non-empty `user_id`s found on other-account rows.
  final Set<String> previousAccountIds;

  final bool hasCurrentUserData;

  int get orphanRows =>
      byTable.values.fold(0, (int sum, t) => sum + t.orphans);

  int get foreignRows =>
      byTable.values.fold(0, (int sum, t) => sum + t.otherAccounts);

  int get currentUserRows =>
      byTable.values.fold(0, (int sum, t) => sum + t.currentUser);

  bool get hasOrphans => orphanRows > 0;

  bool get hasForeignData => foreignRows > 0;

  /// The single distinct previous account id, or null when there is none (or
  /// more than one) distinct account present.
  String? get singlePreviousAccountId =>
      previousAccountIds.length == 1 ? previousAccountIds.first : null;

  /// True when the database holds no user-owned rows at all.
  bool get isEmpty =>
      orphanRows == 0 && foreignRows == 0 && currentUserRows == 0;
}

/// Result of an explicit orphan-adoption run.
class LocalDataAdoptionResult {
  const LocalDataAdoptionResult({
    required this.adoptedRows,
    required this.byTable,
  });

  final int adoptedRows;
  final Map<String, int> byTable;

  bool get isEmpty => adoptedRows == 0;
}

/// Tables whose NULL-`user_id` rows are master catalog data (seeded locally or
/// pulled by master-data sync), NOT orphaned user rows. These NULL rows are
/// excluded from orphan counting and are never adopted.
const Set<String> _masterHybridTables = <String>{
  'exercise',
  'food_item',
  'fitness_goal',
};

/// Classifies user-owned rows against the authenticated user and provides the
/// explicit opt-in adoption path for orphaned rows (PROMPT 17).
class LocalDataOwnershipAnalyzer {
  LocalDataOwnershipAnalyzer({required this.database});

  final AppDatabase database;

  static bool _isMasterHybrid(String table) =>
      _masterHybridTables.contains(table);

  /// Rows of a hybrid master table that participate in ownership classification.
  ///
  /// * `exercise` / `food_item`: only custom rows (`is_custom = 1`) - master
  ///   catalog rows are excluded entirely. A custom row may still be orphaned
  ///   (NULL/empty `user_id`), which the classification below then counts.
  /// * `fitness_goal`: only rows that carry a user (master templates have
  ///   `user_id IS NULL`); there is no orphan state for goals.
  static String _hybridUserWhere(String table) =>
      table == 'fitness_goal'
          ? 'user_id IS NOT NULL AND user_id != \'\''
          : 'is_custom = 1';

  /// Classifies every user-owned table against [userId]. Never mutates data.
  Future<OwnershipAnalysis> analyze(String userId) async {
    final Database db = await database.database;
    final Map<String, LocalTableOwnership> byTable = <String, LocalTableOwnership>{};
    final Set<String> previousAccountIds = <String>{};
    var hasCurrentUserData = false;

    for (final SyncTableMapping mapping in SyncTableRegistry.mappings) {
      final String table = mapping.localTable;
      final bool hybrid = _isMasterHybrid(table);

      // For hybrid master tables only user rows participate; master rows
      // (user_id NULL) are excluded from the analysis entirely.
      final String where = hybrid ? _hybridUserWhere(table) : '1 = 1';
      final List<Map<String, Object?>> grouped = await db.rawQuery(
        'SELECT user_id, COUNT(*) AS c FROM $table WHERE $where GROUP BY user_id',
      );

      var current = 0;
      var other = 0;
      var orphan = 0;
      for (final Map<String, Object?> row in grouped) {
        final Object? uid = row['user_id'];
        final int count = (row['c'] as num).toInt();
        if (uid == null || (uid is String && uid.isEmpty)) {
          orphan += count;
        } else if (uid == userId) {
          current += count;
          hasCurrentUserData = true;
        } else {
          other += count;
          previousAccountIds.add(uid as String);
        }
      }

      if (current != 0 || other != 0 || orphan != 0) {
        byTable[table] = LocalTableOwnership(
          table: table,
          currentUser: current,
          otherAccounts: other,
          orphans: orphan,
        );
      }
    }

    return OwnershipAnalysis(
      byTable: byTable,
      previousAccountIds: previousAccountIds,
      hasCurrentUserData: hasCurrentUserData,
    );
  }

  /// Explicit opt-in adoption: reassigns orphaned rows to [userId] and enqueues
  /// their CREATE outbox events atomically with the mutation.
  ///
  /// Never touches rows owned by another account, never touches master-hybrid
  /// rows (master catalog data), and never adopts singleton tables
  /// (`user_profile`, `app_settings`, `user_level` - those are created fresh on
  /// sign-in).
  Future<LocalDataAdoptionResult> adoptOrphans({required String userId}) async {
    final Database db = await database.database;
    final Map<String, int> byTable = <String, int>{};
    var total = 0;

    await db.transaction((Transaction txn) async {
      for (final SyncTableMapping mapping in SyncTableRegistry.mappings) {
        final String table = mapping.localTable;

        // Singletons are keyed by user_id and created fresh on sign-in; there
        // is nothing to adopt.
        if (mapping.localKeyColumn == 'user_id') continue;

        // fitness_goal NULL rows are master templates, never orphans.
        if (_isMasterHybrid(table) && table == 'fitness_goal') continue;

        final String where = _isMasterHybrid(table)
            ? 'is_custom = 1 AND (user_id IS NULL OR user_id = \'\')'
            : 'user_id IS NULL OR user_id = \'\'';
        final List<Map<String, Object?>> rows = await txn.query(table, where: where);
        if (rows.isEmpty) continue;

        final int now = SyncableDao.nowMs();
        for (final Map<String, Object?> row in rows) {
          final int rowId = (row['id'] as num).toInt();
          final String? existingUuid = row['uuid'] as String?;
          final String uuid = (existingUuid == null || existingUuid.isEmpty)
              ? UuidGenerator.v4()
              : existingUuid;
          final int baseVersion =
              (row['row_version'] as num?)?.toInt() ?? 0;

          await txn.update(
            table,
            <String, Object?>{
              'user_id': userId,
              'uuid': uuid,
              'updated_at': now,
              'row_version': baseVersion + 1,
            },
            where: 'id = ?',
            whereArgs: <Object?>[rowId],
          );

          final String entityId =
              mapping.localKeyColumn == 'uuid' ? uuid : '$rowId';
          await SyncableDao.recordCreate(
            txn,
            entity: table,
            entityId: entityId,
            userId: userId,
          );
        }
        byTable[table] = rows.length;
        total += rows.length;
      }
    });

    return LocalDataAdoptionResult(adoptedRows: total, byTable: byTable);
  }
}