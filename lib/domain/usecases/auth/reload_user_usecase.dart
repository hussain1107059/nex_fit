import '../../../core/errors/failure_mapper.dart';
import '../../../core/utils/result.dart';
import '../../entities/app_user.dart';
import '../../repositories/auth_repository.dart';

/// Reloads the current user's Firebase profile and returns the fresh
/// [AppUser] so the UI can pick up verification status changes.
class ReloadUserUsecase {
  const ReloadUserUsecase(this._repository);

  final AuthRepository _repository;

  Future<Result<AppUser?>> call() async {
    try {
      final AppUser? user = await _repository.reloadUser();
      return Result.success(user);
    } catch (error) {
      return Result.failure(FailureMapper.from(error));
    }
  }
}
