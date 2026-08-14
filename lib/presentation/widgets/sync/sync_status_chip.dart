import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../providers/sync_providers.dart';

/// A user-facing sync state for status chips — decoupled from the provider
/// enum so the mapping is pure and unit-testable.
///
/// These are the only sync states the UI ever renders. Technical details
/// (SQL/Supabase codes, tokens, stack traces) are never surfaced here.
enum SyncStatusKind {
  synced,
  syncing,
  offline,
  failed,
  conflict,
  pendingChanges,
  idle,
}

/// Maps the engine status to a display kind.
SyncStatusKind syncStatusKindOf(SyncUiStatus status) {
  return switch (status) {
    SyncUiStatus.syncing => SyncStatusKind.syncing,
    SyncUiStatus.success => SyncStatusKind.synced,
    SyncUiStatus.offline => SyncStatusKind.offline,
    SyncUiStatus.error => SyncStatusKind.failed,
    SyncUiStatus.conflict => SyncStatusKind.conflict,
    SyncUiStatus.partialFailure => SyncStatusKind.pendingChanges,
    SyncUiStatus.idle => SyncStatusKind.idle,
  };
}

/// Minimal sync status chip (✓ Synced / ↻ Syncing… / Offline / Sync failed /
/// Conflict needs attention).
///
/// Renders exactly one of the [SyncStatusKind] states; never any raw error
/// text. The compact variant is used as the subtle dashboard indicator.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({super.key, required this.status, this.compact = false});

  /// The live engine status (watch `syncStatusProvider` and pass
  /// `snapshot.status`).
  final SyncUiStatus status;

  /// Compact pill for small footprints (dashboard); false renders a larger,
  /// tappable-ready pill for settings.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final SyncStatusKind kind = syncStatusKindOf(status);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (IconData, Color) presentation = _presentation(kind, scheme);
    final String label = _label(context, kind);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.sm : AppSpacing.md,
        vertical: compact ? 4 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: presentation.$2.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            presentation.$1,
            size: compact ? 14 : 18,
            color: presentation.$2,
          ),
          if (!compact) const SizedBox(width: AppSpacing.xs),
          if (!compact)
            Text(
              label,
              style: context.textTheme.labelLarge?.copyWith(
                color: presentation.$2,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  String _label(BuildContext context, SyncStatusKind kind) {
    return switch (kind) {
      SyncStatusKind.synced => context.l10n.syncStatusSynced,
      SyncStatusKind.syncing => context.l10n.settingsSyncInProgress,
      SyncStatusKind.offline => context.l10n.syncStatusOffline,
      SyncStatusKind.failed => context.l10n.syncStatusFailed,
      SyncStatusKind.conflict => context.l10n.syncStatusConflict,
      SyncStatusKind.pendingChanges => context.l10n.syncStatusPending,
      SyncStatusKind.idle => context.l10n.syncStatusNotSynced,
    };
  }

  (IconData, Color) _presentation(
    SyncStatusKind kind,
    ColorScheme scheme,
  ) {
    return switch (kind) {
      SyncStatusKind.synced => (Icons.check_circle_rounded, Colors.green.shade700),
      SyncStatusKind.syncing => (
        Icons.sync_rounded,
        scheme.primary,
      ),
      SyncStatusKind.offline => (
        Icons.cloud_off_rounded,
        scheme.onSurfaceVariant,
      ),
      SyncStatusKind.failed => (
        Icons.error_rounded,
        scheme.error,
      ),
      SyncStatusKind.conflict => (
        Icons.warning_amber_rounded,
        Colors.amber.shade800,
      ),
      SyncStatusKind.pendingChanges => (
        Icons.cloud_sync_rounded,
        Colors.orange.shade800,
      ),
      SyncStatusKind.idle => (
        Icons.sync_disabled_rounded,
        scheme.onSurfaceVariant,
      ),
    };
  }
}