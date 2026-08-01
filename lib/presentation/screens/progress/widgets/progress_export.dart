import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../data/services/report/report_exporter.dart';
import '../../../../domain/entities/progress/analytics_report.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../injection/dependency_injection.dart';

/// Shows a bottom sheet offering PDF / CSV / Excel export for [report].
Future<void> showProgressExportSheet(
  BuildContext context,
  AnalyticsReport report,
) async {
  final AppLocalizations l10n = context.l10n;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                l10n.progressExportTitle,
                style: sheetContext.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                l10n.progressExportSubtitle,
                style: sheetContext.textTheme.bodySmall?.copyWith(
                  color: sheetContext.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _ExportTile(
                icon: Icons.picture_as_pdf_rounded,
                label: l10n.progressExportPdf,
                color: const Color(0xFFEF4444),
                report: report,
                format: ReportFormat.pdf,
              ),
              const SizedBox(height: AppSpacing.xs),
              _ExportTile(
                icon: Icons.grid_on_rounded,
                label: l10n.progressExportCsv,
                color: const Color(0xFF0E9F6E),
                report: report,
                format: ReportFormat.csv,
              ),
              const SizedBox(height: AppSpacing.xs),
              _ExportTile(
                icon: Icons.table_chart_rounded,
                label: l10n.progressExportExcel,
                color: const Color(0xFF217346),
                report: report,
                format: ReportFormat.excel,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _ExportTile extends ConsumerWidget {
  const _ExportTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.report,
    required this.format,
  });

  final IconData icon;
  final String label;
  final Color color;
  final AnalyticsReport report;
  final ReportFormat format;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: context.colorScheme.surface,
      borderRadius: AppRadius.mdRadius,
      child: InkWell(
        onTap: () {
          Navigator.of(context).pop();
          _runExport(context, ref);
        },
        borderRadius: AppRadius.mdRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.mdRadius,
            border: Border.all(color: context.colorScheme.outlineVariant),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  label,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.ios_share_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runExport(BuildContext context, WidgetRef ref) async {
    final AppLocalizations l10n = context.l10n;
    AppSnackbar.info(context, l10n.progressExporting);
    try {
      final ReportExporter exporter = ref.read(reportExporterProvider);
      final String path = await exporter.export(report, format);
      await exporter.share(path);
      if (context.mounted) {
        AppSnackbar.success(context, l10n.progressExported);
      }
    } catch (_) {
      if (context.mounted) {
        AppSnackbar.error(context, l10n.progressExportFailed);
      }
    }
  }
}
