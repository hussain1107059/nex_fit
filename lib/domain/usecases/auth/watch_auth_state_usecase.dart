import '../../../core/errors/failure_mapper.dart';
import '../../../core/utils/result.dart';
import '../../entities/app_user.dart';
import '../../repositories/auth_repository.dart';

/// Watches the authentication state and emits the current [AppUser].
class WatchAuthStateUsecase {
  const WatchAuthStateUsecase(this._repository);

  final AuthRepository _repository;

  Stream<AppUser?> call() => _repository.authStateChanges;

  Future<Result<AppUser?>> getCurrentUser() async {
    try {
      final AppUser? user = await _repository.getCurrentUser();
      return Result.success(user);
    } catch (error) {
      return Result.failure(FailureMapper.from(error));
    }
  }
}
