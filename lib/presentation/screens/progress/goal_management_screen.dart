import 'package:flutter/material.dart' hide ErrorWidget;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/cards/app_card.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/feedback/empty_widget.dart';
import '../../../core/widgets/feedback/error_widget.dart';
import '../../../core/widgets/feedback/loading_widget.dart';
import '../../../domain/entities/common_enums.dart';
import '../../../domain/entities/fitness_goal.dart';
import '../../../domain/entities/progress/goal_progress.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/fitness_goal_providers.dart';
import '../../providers/progress_providers.dart';
import 'widgets/goal_editor_sheet.dart';

/// Manage the user's own fitness goals and adopt server-authoritative
/// templates. Every create/update/delete writes a sync event through the
/// existing engine.
class GoalManagementScreen extends ConsumerWidget {
  const GoalManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FitnessGoal>> async =
        ref.watch(userGoalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.goalManagementTitle),
        actions: <Widget>[
          IconButton(
            onPressed: () => showGoalEditorSheet(context, ref),
            icon: const Icon(Icons.add_rounded),
            tooltip: context.l10n.goalAdd,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: async.when(
        loading: () => const LoadingWidget(),
        error: (Object error, StackTrace stackTrace) => ErrorWidget(
          title: context.l10n.errorDatabase,
          subtitle: context.l10n.errorDatabaseSubtitle,
          onRetry: () => ref.invalidate(userGoalsProvider),
        ),
        data: (List<FitnessGoal> goals) => _GoalManagementContent(
          goals: goals,
          progressAsync: ref.watch(goalProgressProvider),
          templatesAsync: ref.watch(goalTemplatesProvider),
        ),
      ),
    );
  }
}

class _GoalManagementContent extends ConsumerWidget {
  const _GoalManagementContent({
    required this.goals,
    required this.progressAsync,
    required this.templatesAsync,
  });

  final List<FitnessGoal> goals;
  final AsyncValue<List<GoalProgress>> progressAsync;
  final AsyncValue<List<FitnessGoal>> templatesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<GoalProgress> progress = progressAsync.value ?? const <GoalProgress>[];
    final List<FitnessGoal> templates = templatesAsync.value ?? const <FitnessGoal>[];
    final Set<GoalType> owned = goals.map((FitnessGoal g) => g.goalType).toSet();
    final List<FitnessGoal> adoptable = templates
        .where((FitnessGoal t) => !owned.contains(t.goalType))
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xxl,
      ),
      children: <Widget>[
        Text(
          l10n.goalManagementSubtitle,
          style: context.textTheme.bodySmall?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (goals.isEmpty)
          _EmptyGoals(
            onAdd: () => showGoalEditorSheet(context, ref),
          )
        else ...<Widget>[
          for (int i = 0; i < goals.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _GoalTile(
              goal: goals[i],
              progress: _matchingProgress(goals[i], progress),
              onEdit: () => showGoalEditorSheet(context, ref, existing: goals[i]),
              onDelete: () => _deleteGoal(context, ref, goals[i]),
            ),
          ],
        ],
        if (adoptable.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.goalTemplates,
            style: context.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (int i = 0; i < adoptable.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _TemplateTile(
              template: adoptable[i],
              onAdopt: () async {
                await createGoalFromTemplate(ref, adoptable[i]);
                if (context.mounted) {
                  AppSnackbar.success(context, l10n.goalTemplateUsed);
                }
              },
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _deleteGoal(
    BuildContext context,
    WidgetRef ref,
    FitnessGoal goal,
  ) async {
    final AppLocalizations l10n = context.l10n;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(l10n.goalDeleteConfirm),
        content: Text(l10n.goalDeleteMessage),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await deleteUserGoal(ref, goal.id!);
    if (context.mounted) {
      AppSnackbar.success(context, l10n.goalDeleted);
    }
  }

  GoalProgress? _matchingProgress(
    FitnessGoal goal,
    List<GoalProgress> progress,
  ) {
    final GoalKind kind = _kindForType(goal.goalType);
    for (final GoalProgress item in progress) {
      if (item.kind == kind) return item;
    }
    return null;
  }

  GoalKind _kindForType(GoalType type) {
    return switch (type) {
      GoalType.weightLoss ||
      GoalType.weightGain ||
      GoalType.maintainWeight => GoalKind.weight,
      GoalType.muscleBuilding ||
      GoalType.generalFitness ||
      GoalType.other => GoalKind.workout,
    };
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.progress,
    required this.onEdit,
    required this.onDelete,
  });

  final FitnessGoal goal;
  final GoalProgress? progress;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = AppColors.light;
    final bool done = goal.status == GoalStatus.completed;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.flag_rounded,
                size: 18,
                color: done ? colors.success : colors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  goal.title,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _StatusChip(status: goal.status),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                onSelected: (String value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'edit',
                    child: Text(l10n.goalEdit),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(l10n.goalDelete),
                  ),
                ],
              ),
            ],
          ),
          if (goal.targetValue != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _GoalProgressRow(l10n: l10n, goal: goal, progress: progress),
          ],
          if (goal.targetDate != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${l10n.progressDaysLeft} '
              '${_daysLeft(goal.targetDate!).toString().toBanglaDigits()}',
              style: context.textTheme.labelSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  int _daysLeft(DateTime date) {
    final int days = date.difference(DateTime.now()).inDays;
    return days < 0 ? 0 : days;
  }
}

class _GoalProgressRow extends StatelessWidget {
  const _GoalProgressRow({
    required this.l10n,
    required this.goal,
    required this.progress,
  });

  final AppLocalizations l10n;
  final FitnessGoal goal;
  final GoalProgress? progress;

  @override
  Widget build(BuildContext context) {
    final GoalProgress? item = progress;
    if (item == null || !item.hasTarget || item.target <= 0) {
      return Text(
        '${l10n.goalTargetValue}: '
        '${_format(goal.targetValue)}'.toBanglaDigits(),
        style: context.textTheme.bodySmall,
      );
    }
    final bool done = item.fraction >= 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ClipRRect(
          borderRadius: AppRadius.pillRadius,
          child: LinearProgressIndicator(
            value: item.fraction,
            minHeight: 6,
            backgroundColor: AppColors.light.primary.withValues(alpha: 0.16),
            color: done ? AppColors.light.success : AppColors.light.primary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                '${l10n.goalCurrentValue}: '
                '${_format(item.current)} ${_unit(l10n, item.unit)}'
                    .toBanglaDigits(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.labelSmall,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '${item.percent.round().toString().toBanglaDigits()}%',
              style: context.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: done ? AppColors.light.success : AppColors.light.primary,
              ),
            ),
          ],
        ),
        if (item.streak > 0) ...<Widget>[
          const SizedBox(height: 2),
          Row(
            children: <Widget>[
              Icon(
                Icons.local_fire_department_rounded,
                size: 14,
                color: AppColors.light.warning,
              ),
              const SizedBox(width: 4),
              Text(
                '${item.streak.toString().toBanglaDigits()} '
                '${l10n.progressDayStreak}',
                style: context.textTheme.labelSmall?.copyWith(
                  color: AppColors.light.warning,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _unit(AppLocalizations l10n, String unit) {
    return switch (unit) {
      'kg' => l10n.progressUnitKg,
      'workouts' => l10n.progressUnitWorkouts,
      _ => unit,
    };
  }

  String _format(double? value) {
    if (value == null) return '—';
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final GoalStatus status;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final (String label, Color color) = switch (status) {
      GoalStatus.active => (l10n.goalStatusActive, AppColors.light.primary),
      GoalStatus.completed => (l10n.goalStatusCompleted, AppColors.light.success),
      GoalStatus.abandoned => (l10n.goalStatusAbandoned, AppColors.light.warning),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.pillRadius,
      ),
      child: Text(
        label,
        style: context.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template, required this.onAdopt});

  final FitnessGoal template;
  final VoidCallback onAdopt;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCard(
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  template.title,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (template.description != null) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    template.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.labelSmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton.icon(
            onPressed: onAdopt,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.goalUseTemplate),
          ),
        ],
      ),
    );
  }
}

class _EmptyGoals extends StatelessWidget {
  const _EmptyGoals({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return AppCard(
      child: EmptyWidget(
        icon: Icons.flag_rounded,
        title: l10n.goalEmptyTitle,
        subtitle: l10n.goalEmptySubtitle,
        actionLabel: l10n.goalAdd,
        onActionPressed: onAdd,
      ),
    );
  }
}