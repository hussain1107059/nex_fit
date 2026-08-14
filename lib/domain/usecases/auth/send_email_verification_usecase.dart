import '../../../core/errors/failure_mapper.dart';
import '../../../core/utils/result.dart';
import '../../repositories/auth_repository.dart';

/// Sends a verification email to the current user (or to [email] when the
/// user is not signed in yet).
class SendEmailVerificationUsecase {
  const SendEmailVerificationUsecase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call({String? email}) async {
    try {
      await _repository.sendEmailVerification(email: email);
      return const Result.success(null);
    } catch (error) {
      return Result.failure(FailureMapper.from(error));
    }
  }
}
