import '../../../core/errors/failure_mapper.dart';
import '../../../core/utils/result.dart';
import '../../entities/app_user.dart';
import '../../repositories/auth_repository.dart';

/// Registers a new user with email & password.
class SignUpWithEmailUsecase {
  const SignUpWithEmailUsecase(this._repository);

  final AuthRepository _repository;

  Future<Result<AppUser>> call({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final AppUser user = await _repository.signUpWithEmail(
        name: name,
        email: email,
        password: password,
      );
      return Result.success(user);
    } catch (error) {
      return Result.failure(FailureMapper.from(error));
    }
  }
}
