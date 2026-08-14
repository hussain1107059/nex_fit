import 'package:logging/logging.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'sync_log.dart';

/// Abstraction over a realtime event stream so the notifier is testable without
/// a live Supabase Realtime connection.
abstract interface class RealtimeChannelGateway {
  /// Subscribes to postgres changes on [tables] (schema `public`) and invokes
  /// [onEvent] for every INSERT/UPDATE/DELETE. Idempotent until [close].
  void subscribeToChanges({
    required List<String> tables,
    required void Function() onEvent,
  });

  /// Unsubscribes every channel opened by [subscribeToChanges].
  void close();

  /// Whether the gateway currently has live subscriptions.
  bool get isActive;
}

/// Real [supabase.SupabaseClient]-backed gateway.
///
/// Subscribes one channel per table. Supabase Realtime enforces RLS, so events
/// are delivered only for the signed-in user's own rows. The callback carries
/// no row data — Realtime is used purely as a "something changed, sync now"
/// signal (PROMPT 18); the authoritative cursor pull fetches the actual rows.
class SupabaseRealtimeChannelGateway implements RealtimeChannelGateway {
  SupabaseRealtimeChannelGateway(this._client, {Logger? logger})
      : _logger = logger ?? Logger('SupabaseRealtimeChannelGateway');

  final supabase.SupabaseClient _client;
  final Logger _logger;

  final List<supabase.RealtimeChannel> _channels = <supabase.RealtimeChannel>[];
  bool _active = false;

  @override
  bool get isActive => _active;

  @override
  void subscribeToChanges({
    required List<String> tables,
    required void Function() onEvent,
  }) {
    if (_active) return;
    _active = true;
    for (final String table in tables) {
      final supabase.RealtimeChannel channel = _client
          .channel('incremental_sync:$table')
          .onPostgresChanges(
            event: supabase.PostgresChangeEvent.all,
            schema: 'public',
            table: table,
              callback: (supabase.PostgresChangePayload payload) {
                SyncLog.info(
                  _logger,
                  SyncLog.start,
                  'realtime ${payload.eventType} ${payload.table} '
                  '${payload.newRecord['id'] ?? payload.oldRecord['id']}',
                );
                onEvent();
              },
          )
          .subscribe();
      _channels.add(channel);
    }
    SyncLog.info(_logger, SyncLog.start, 'subscribed to ${tables.length} tables');
  }

  @override
  void close() {
    if (!_active) return;
    for (final supabase.RealtimeChannel channel in _channels) {
      _client.removeChannel(channel);
    }
    _channels.clear();
    _active = false;
  }
}

/// Realtime notification channel for incremental sync (PROMPT 18).
///
/// Realtime is **notification-only**: [attach] opens subscriptions for the
/// realtime-enabled user tables and forwards every change to [onRemoteChange]
/// (a [`IncrementalSyncCoordinator.requestSync`] call). It never applies a row
/// and never advances the sync cursor, so a missed or duplicated Realtime event
/// can never corrupt data — the cursor-based incremental pull is authoritative
/// and idempotent, and recovers anything Realtime dropped.
class RealtimeSyncNotifier {
  RealtimeSyncNotifier({required this.gateway});

  final RealtimeChannelGateway gateway;

  /// Tables enabled in the `supabase_realtime` publication (cloud migration
  /// `001_initial_nexfit_schema.sql` §9). High-volume append-only logs
  /// deliberately stay out of Realtime and rely on cursor sync.
  static const List<String> realtimeTables = <String>[
    'daily_progress',
    'food_logs',
    'water_logs',
    'weight_logs',
    'workouts',
    'workout_history',
    'reminders',
    'sleep_logs',
    'step_logs',
    'body_measurements',
    'bmi_logs',
    'streaks',
  ];

  void Function()? onRemoteChange;

  bool _attached = false;

  bool get isActive => _attached;

  /// Opens the Realtime subscriptions. No-op when already attached.
  void attach() {
    if (_attached) return;
    _attached = true;
    gateway.subscribeToChanges(
      tables: realtimeTables,
      onEvent: _handleEvent,
    );
  }

  /// Closes every Realtime subscription.
  void detach() {
    if (!_attached) return;
    _attached = false;
    gateway.close();
  }

  void _handleEvent() => onRemoteChange?.call();
}
