import '../../../core/errors/failure_mapper.dart';
import '../../../core/utils/result.dart';
import '../../entities/app_user.dart';
import '../../repositories/auth_repository.dart';

/// Signs the user in with their Google account.
class SignInWithGoogleUsecase {
  const SignInWithGoogleUsecase(this._repository);

  final AuthRepository _repository;

  Future<Result<AppUser>> call() async {
    try {
      final AppUser user = await _repository.signInWithGoogle();
      return Result.success(user);
    } catch (error) {
      return Result.failure(FailureMapper.from(error));
    }
  }
}
