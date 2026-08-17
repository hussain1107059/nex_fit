import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../core/utils/release_logger.dart';
import '../../data/services/supabase/supabase_service.dart';
import '../../data/services/sync/incremental_sync_coordinator.dart';
import '../../data/services/sync/realtime_sync_notifier.dart';
import '../../domain/entities/app_user.dart';
import '../../injection/dependency_injection.dart';
import 'auth_provider.dart';
import 'sync_providers.dart';

/// Interval for the periodic foreground sync. A missed Realtime event or a
/// locally queued mutation is caught up within this window even when the app
/// stays open and no other trigger fires.
const Duration periodicSyncInterval = Duration(seconds: 30);

/// No-op gateway used on offline-first builds (no Supabase configuration), so
/// the notifier stays inactive instead of throwing.
class _NoopRealtimeChannelGateway implements RealtimeChannelGateway {
  const _NoopRealtimeChannelGateway();

  @override
  bool get isActive => false;

  @override
  void subscribeToChanges({
    required List<String> tables,
    required void Function() onEvent,
  }) {}

  @override
  void close() {}
}

/// Event-driven trigger hub for incremental synchronization (PROMPT 18).
///
/// Reading this provider activates the hub: it opens Realtime subscriptions for
/// the signed-in user, watches connectivity for offline→online recovery and
/// fires on startup / resume / login / Realtime / manual via
/// [IncrementalSyncCoordinator.requestSync]. All triggers funnel into the same
/// cursor-based incremental pull, so a missed Realtime event is recovered by the
/// next startup/resume/manual run.
final incrementalSyncCoordinatorProvider =
    Provider<IncrementalSyncCoordinator>((ref) {
  final SupabaseService supabaseService = ref.read(supabaseServiceProvider);
  final supabase.SupabaseClient? client = supabaseService.client;
  final RealtimeChannelGateway gateway = client == null
      ? const _NoopRealtimeChannelGateway()
      : SupabaseRealtimeChannelGateway(client);

  final RealtimeSyncNotifier realtime = RealtimeSyncNotifier(gateway: gateway);

  final IncrementalSyncCoordinator coordinator = IncrementalSyncCoordinator(
    canSync: () {
      final AppUser? user = ref.read(currentUserProvider);
      return user != null && user.isSignedIn;
    },
    onSync: (SyncTrigger trigger) {
      devLog('[SYNC] incremental run triggered by ${trigger.name}');
      return ref
          .read(syncControllerProvider.notifier)
          .runSync(trigger: trigger);
    },
  );
  realtime.onRemoteChange = () =>
      coordinator.requestSync(SyncTrigger.realtime);

  final StreamSubscription<List<ConnectivityResult>> connectivitySub = ref
      .read(networkInfoProvider)
      .onConnectivityChanged
      .listen((List<ConnectivityResult> results) {
    final bool online = results.any(
      (ConnectivityResult result) => result != ConnectivityResult.none,
    );
    if (online) {
      coordinator.requestSync(SyncTrigger.networkRecovery);
    }
  });

  // Periodic foreground sync (PROMPT 36): while the app is open and a user is
  // signed in, a 30s timer issues a debounced sync so a missed Realtime event
  // or a locally queued mutation reaches the cloud even when no other trigger
  // fires. The coordinator already single-flights and coalesces bursts, so the
  // timer is cheap and never overlaps a running sync. Requests are dropped
  // while signed out (canSync), which keeps the timer silent on the login
  // screen.
  final Timer periodicTimer = Timer.periodic(periodicSyncInterval, (Timer _) {
    coordinator.requestSync(SyncTrigger.periodic);
  });

  void syncRealtimeForUser(AppUser? user) {
    final bool signedIn = user != null && user.isSignedIn;
    if (signedIn && !realtime.isActive) {
      realtime.attach();
    } else if (!signedIn && realtime.isActive) {
      realtime.detach();
    }
  }

  syncRealtimeForUser(ref.read(currentUserProvider));

  ref.listen<AppUser?>(currentUserProvider, (AppUser? prev, AppUser? next) {
    syncRealtimeForUser(next);
    final bool wasSignedIn = prev != null && prev.isSignedIn;
    final bool isSignedIn = next != null && next.isSignedIn;
    if (isSignedIn && !wasSignedIn) {
      coordinator.requestSync(SyncTrigger.login);
    }
  });

  ref.onDispose(() {
    periodicTimer.cancel();
    connectivitySub.cancel();
    realtime.detach();
    coordinator.dispose();
  });

  return coordinator;
});
