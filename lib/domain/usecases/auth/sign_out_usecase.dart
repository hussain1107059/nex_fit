import '../../../core/errors/failure_mapper.dart';
import '../../../core/utils/result.dart';
import '../../repositories/auth_repository.dart';

/// Signs the current user out of the application.
class SignOutUsecase {
  const SignOutUsecase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call() async {
    try {
      await _repository.signOut();
      return const Result.success(null);
    } catch (error) {
      return Result.failure(FailureMapper.from(error));
    }
  }
}
