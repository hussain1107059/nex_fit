import '../../domain/entities/meal_category.dart';
import '../../domain/repositories/meal_category_repository.dart';
import '../datasources/local/meal_category_local_data_source.dart';

/// SQLite backed implementation of [MealCategoryRepository].
class MealCategoryRepositoryImpl implements MealCategoryRepository {
  const MealCategoryRepositoryImpl(this._dataSource);

  final MealCategoryLocalDataSource _dataSource;

  @override
  Future<int> insert(MealCategory category) => _dataSource.insert(category);

  @override
  Future<MealCategory?> getById(int id) => _dataSource.getById(id);

  @override
  Future<MealCategory?> getBySlug(String slug) => _dataSource.getBySlug(slug);

  @override
  Future<List<MealCategory>> getAll() => _dataSource.getAll();
}
