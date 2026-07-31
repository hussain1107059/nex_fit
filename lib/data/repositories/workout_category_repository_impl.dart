import '../../domain/entities/workout_category.dart';
import '../../domain/repositories/workout_category_repository.dart';
import '../datasources/local/workout_category_local_data_source.dart';

/// SQLite backed implementation of [WorkoutCategoryRepository].
class WorkoutCategoryRepositoryImpl implements WorkoutCategoryRepository {
  const WorkoutCategoryRepositoryImpl(this._dataSource);

  final WorkoutCategoryLocalDataSource _dataSource;

  @override
  Future<int> insert(WorkoutCategory category) => _dataSource.insert(category);

  @override
  Future<WorkoutCategory?> getById(int id) => _dataSource.getById(id);

  @override
  Future<WorkoutCategory?> getBySlug(String slug) =>
      _dataSource.getBySlug(slug);

  @override
  Future<List<WorkoutCategory>> getAll() => _dataSource.getAll();
}
