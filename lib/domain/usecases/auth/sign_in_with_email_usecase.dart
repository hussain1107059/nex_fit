import '../../../core/errors/failure_mapper.dart';
import '../../../core/utils/result.dart';
import '../../entities/app_user.dart';
import '../../repositories/auth_repository.dart';

/// Signs the user in using email & password.
class SignInWithEmailUsecase {
  const SignInWithEmailUsecase(this._repository);

  final AuthRepository _repository;

  Future<Result<AppUser>> call({
    required String email,
    required String password,
  }) async {
    try {
      final AppUser user = await _repository.signInWithEmail(
        email: email,
        password: password,
      );
      return Result.success(user);
    } catch (error) {
      return Result.failure(FailureMapper.from(error));
    }
  }
}
