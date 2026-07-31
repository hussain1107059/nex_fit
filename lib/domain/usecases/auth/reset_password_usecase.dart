import '../../../core/errors/failure_mapper.dart';
import '../../../core/utils/result.dart';
import '../../repositories/auth_repository.dart';

/// Sends a password reset email to the given address.
class ResetPasswordUsecase {
  const ResetPasswordUsecase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call({required String email}) async {
    try {
      await _repository.resetPassword(email);
      return const Result.success(null);
    } catch (error) {
      return Result.failure(FailureMapper.from(error));
    }
  }
}
