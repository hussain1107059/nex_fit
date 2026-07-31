import 'package:equatable/equatable.dart';

/// Base class for all application-level exceptions.
/// Implementations carry a user-facing message that can be localized.
class AppException extends Equatable implements Exception {
  const AppException(this.message, {this.code = 'app_error'});

  final String message;
  final String code;

  @override
  List<Object?> get props => [message, code];

  @override
  String toString() => 'AppException(code: $code, message: $message)';
}

class NetworkException extends AppException {
  const NetworkException(super.message, {super.code = 'network_error'});
}

class ServerException extends AppException {
  const ServerException(super.message, {super.code = 'server_error'});
}

class AuthException extends AppException {
  const AuthException(super.message, {super.code = 'auth_error'});
}

class CacheException extends AppException {
  const CacheException(super.message, {super.code = 'cache_error'});
}

class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.code = 'database_error'});
}

class BackupException extends AppException {
  const BackupException(super.message, {super.code = 'backup_error'});
}

class PermissionException extends AppException {
  const PermissionException(super.message, {super.code = 'permission_error'});
}

class TimeoutException extends AppException {
  const TimeoutException(super.message, {super.code = 'timeout_error'});
}
