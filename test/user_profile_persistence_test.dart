import 'package:flutter_test/flutter_test.dart';
import 'package:nexfit/data/datasources/local/app_database.dart';
import 'package:nexfit/data/datasources/local/user_local_data_source.dart';
import 'package:nexfit/domain/entities/app_user.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late AppDatabase appDatabase;
  late UserLocalDataSource dataSource;
  late Database db;

  setUp(() async {
    appDatabase = AppDatabase(databaseName: 'user_profile_persistence_test.db');
    db = await appDatabase.database;
    dataSource = UserLocalDataSource(database: appDatabase);
  });

  tearDown(() async {
    await appDatabase.close();
    await databaseFactory.deleteDatabase('user_profile_persistence_test.db');
  });

  test('re-saving the profile preserves child rows (no cascade wipe)',
      () async {
    await db.insert('users', <String, Object?>{
      'id': 'user-1',
      'name': 'Alice',
      'email': 'alice@x.com',
      'provider': 'email',
    });
    await db.insert('weight_log', <String, Object?>{
      'id': 1,
      'uuid': 'wl-1',
      'user_id': 'user-1',
      'weight_kg': 82.5,
      'logged_at': DateTime.utc(2026, 1, 5).millisecondsSinceEpoch,
      'created_at': DateTime.utc(2026, 1, 5).millisecondsSinceEpoch,
      'updated_at': DateTime.utc(2026, 1, 5).millisecondsSinceEpoch,
      'row_version': 1,
    });

    // Sign-in flow re-persists the profile for the SAME user id.
    await dataSource.saveProfile(
      AppUser(
        id: 'user-1',
        email: 'alice@x.com',
        displayName: 'Alice Updated',
        provider: AuthProvider.email,
        isEmailVerified: true,
      ),
    );

    final List<Map<String, Object?>> weightRows = await db.query(
      'weight_log',
      where: 'user_id = ?',
      whereArgs: <Object?>['user-1'],
    );
    expect(weightRows, hasLength(1), reason: 'child rows must survive re-login');

    final List<Map<String, Object?>> userRows = await db.query('users');
    expect(userRows, hasLength(1));
    expect(userRows.single['name'], 'Alice Updated');
  });
}