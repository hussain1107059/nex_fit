import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../datasources/local/app_settings_local_data_source.dart';

/// SQLite backed implementation of [AppSettingsRepository].
class AppSettingsRepositoryImpl implements AppSettingsRepository {
  const AppSettingsRepositoryImpl(this._dataSource);

  final AppSettingsLocalDataSource _dataSource;

  @override
  Future<void> upsert(AppSettings settings, {bool trackSync = true}) async {
    await _dataSource.upsert(settings, trackSync: trackSync);
  }

  @override
  Future<AppSettings?> getByUserId(String userId) =>
      _dataSource.getByUserId(userId);

  @override
  Future<void> delete(String userId) => _dataSource.delete(userId);
}
