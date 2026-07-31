import 'package:equatable/equatable.dart';

/// Domain-level failure model returned by use cases.
/// [message] is a translation key when it starts with 'error_' / 'empty_' /
/// 'auth_' / 'connectivity_' or a raw human readable string otherwise.
class Failure extends Equatable {
  const Failure({
    required this.message,
    this.code,
    this.exception,
  });

  final String message;
  final String? code;
  final Object? exception;

  @override
  List<Object?> get props => [message, code, exception];

  @override
  String toString() => 'Failure(message: $message, code: $code)';
}
