import '../../../core/errors/failure_mapper.dart';
import '../../../core/utils/result.dart';
import '../../repositories/auth_repository.dart';

/// Sends a verification email to the currently signed-in user.
class SendEmailVerificationUsecase {
  const SendEmailVerificationUsecase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call() async {
    try {
      await _repository.sendEmailVerification();
      return const Result.success(null);
    } catch (error) {
      return Result.failure(FailureMapper.from(error));
    }
  }
}
