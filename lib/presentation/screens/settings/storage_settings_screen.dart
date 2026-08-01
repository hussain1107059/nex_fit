import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/dialogs/app_dialog.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../injection/dependency_injection.dart';
import '../../providers/settings_providers.dart';
import 'widgets/settings_widgets.dart';

/// Storage usage: database + image cache sizes and maintenance actions.
class StorageSettingsScreen extends ConsumerWidget {
  const StorageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final databaseBytes = ref.watch(databaseSizeProvider);
    final imageBytes = ref.watch(imageCacheSizeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsStorage)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          SettingsSectionTitle(context.l10n.settingsStorageUsage),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.dataset_rounded,
                title: context.l10n.settingsDatabaseSize,
                value: _formatBytes(
                  context,
                  databaseBytes.valueOrNull,
                ),
                showChevron: false,
                onTap: null,
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.photo_library_rounded,
                title: context.l10n.settingsImageCacheSize,
                value: _formatBytes(context, imageBytes.valueOrNull),
                showChevron: false,
                onTap: null,
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsStorageActions),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.cleaning_services_rounded,
                title: context.l10n.settingsClearImageCache,
                onTap: () => _clearImageCache(context, ref),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.speed_rounded,
                title: context.l10n.settingsOptimizeDatabase,
                subtitle: context.l10n.settingsOptimizeDatabaseSubtitle,
                onTap: () => _optimizeDatabase(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatBytes(BuildContext context, int? bytes) {
    if (bytes == null) return context.l10n.settingsCalculating;
    if (bytes < 1024) return '${bytes.toString()} B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _clearImageCache(BuildContext context, WidgetRef ref) async {
    await ref.read(settingsStorageServiceProvider).clearPhotoCache();
    ref.invalidate(imageCacheSizeProvider);
    if (context.mounted) {
      AppSnackbar.success(context, context.l10n.settingsCacheCleared);
    }
  }

  Future<void> _optimizeDatabase(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await AppDialog.confirm(
      context: context,
      title: context.l10n.settingsOptimizeDatabase,
      message: context.l10n.settingsOptimizeDatabaseConfirm,
      confirmLabel: context.l10n.settingsOptimizeDatabaseAction,
    );
    if (confirmed != true || !context.mounted) return;

    await ref.read(settingsStorageServiceProvider).optimizeDatabase();
    ref.invalidate(databaseSizeProvider);
    if (context.mounted) {
      AppSnackbar.success(context, context.l10n.settingsOptimizeDatabaseDone);
    }
  }
}
