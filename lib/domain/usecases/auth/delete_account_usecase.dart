import '../../../core/errors/failure_mapper.dart';
import '../../../core/utils/result.dart';
import '../../repositories/auth_repository.dart';

/// Permanently deletes the signed-in authentication account.
class DeleteAccountUsecase {
  const DeleteAccountUsecase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call() async {
    try {
      await _repository.deleteAccount();
      return const Result.success(null);
    } catch (error) {
      return Result.failure(FailureMapper.from(error));
    }
  }
}
