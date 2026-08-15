import '../../../core/errors/failure_mapper.dart';
import '../../../core/utils/result.dart';
import '../../repositories/auth_repository.dart';

/// Changes the signed-in user's password.
class UpdatePasswordUsecase {
  const UpdatePasswordUsecase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call({required String newPassword}) async {
    try {
      await _repository.updatePassword(newPassword: newPassword);
      return const Result.success(null);
    } catch (error) {
      return Result.failure(FailureMapper.from(error));
    }
  }
}
