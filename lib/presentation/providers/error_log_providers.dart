import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/security/app_error_logger.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';

/// Exposes the structured error log for the developer screen.
class ErrorLogController extends Notifier<AsyncValue<List<dynamic>>> {
  AppErrorLogger get _logger => ref.read(errorLoggerProvider);

  @override
  AsyncValue<List<dynamic>> build() {
    ref.watch(currentUserProvider);
    return const AsyncValue<List<dynamic>>.data(<dynamic>[]);
  }

  Future<void> load() async {
    state = const AsyncValue<List<dynamic>>.loading();
    try {
      final logs = await _logger.recent(limit: 100);
      state = AsyncValue<List<dynamic>>.data(logs);
    } catch (error, stackTrace) {
      state = AsyncValue<List<dynamic>>.error(error, stackTrace);
    }
  }

  Future<void> clear() async {
    await _logger.clearOldLogs();
    await load();
  }
}

final errorLogControllerProvider =
    NotifierProvider<ErrorLogController, AsyncValue<List<dynamic>>>(
      ErrorLogController.new,
    );

/// Total persisted error records for the signed-in user.
final errorLogCountProvider = FutureProvider<int>((ref) {
  ref.watch(currentUserProvider);
  return ref.watch(errorLoggerProvider).count();
});
