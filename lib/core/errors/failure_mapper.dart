import 'app_exception.dart';
import 'failure.dart';

/// Maps exceptions raised in the data layer to domain [Failure]s.
class FailureMapper {
  FailureMapper._();

  static Failure from(
    Object error, {
    String fallbackKey = 'errorUnknown',
  }) {
    if (error is AppException) {
      return Failure(
        message: error.message,
        code: error.code,
        exception: error,
      );
    }
    if (error is Exception) {
      return Failure(
        message: fallbackKey,
        code: 'exception',
        exception: error,
      );
    }
    return Failure(
      message: fallbackKey,
      code: 'unknown',
      exception: error,
    );
  }
}
