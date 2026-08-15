import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_formatting.dart';
import '../../../../core/utils/step_estimator.dart';
import '../../../../core/widgets/buttons/app_button.dart';
import '../../../../core/widgets/feedback/app_snackbar.dart';
import '../../../../domain/entities/bmi_log.dart';
import '../../../../domain/entities/sleep_log.dart';
import '../../../../domain/entities/step_log.dart';
import '../../../../domain/entities/water_log.dart';
import '../../../../domain/entities/weight_log.dart';
import '../../../../injection/dependency_injection.dart';
import '../../../providers/dashboard_providers.dart';

/// Quick-action bottom sheets that write real entries into the local database.
class DashboardDialogs {
  DashboardDialogs._();

  /// Logs a water intake entry and refreshes the dashboard.
  static Future<void> showLogWater(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final int? amount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogWaterSheet(),
    );
    if (amount == null || amount <= 0 || !context.mounted) return;

    await ref.read(waterLogRepositoryProvider).insert(
      WaterLog(
        userId: userId,
        amountMl: amount,
        loggedAt: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );
    if (!context.mounted) return;
    AppSnackbar.success(context, context.l10n.dashboardLogWaterSuccess);
    await ref.read(dashboardControllerProvider.notifier).refresh();
  }

  /// Logs a body weight entry and refreshes the dashboard.
  static Future<void> showLogWeight(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final double? weight = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogWeightSheet(),
    );
    if (weight == null || weight <= 0 || !context.mounted) return;

    await ref.read(weightLogRepositoryProvider).insert(
      WeightLog(
        userId: userId,
        weightKg: weight,
        loggedAt: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );
    if (!context.mounted) return;
    AppSnackbar.success(context, context.l10n.dashboardLogWeightSuccess);
    await ref.read(dashboardControllerProvider.notifier).refresh();
  }

  /// Logs a sleep entry for last night and refreshes the dashboard.
  static Future<void> showLogSleep(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final _SleepResult? result = await showModalBottomSheet<_SleepResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogSleepSheet(),
    );
    if (result == null || result.durationMinutes <= 0 || !context.mounted) {
      return;
    }

    await ref.read(sleepLogRepositoryProvider).insert(
      SleepLog(
        userId: userId,
        sleepDate: DateTime.now(),
        durationMinutes: result.durationMinutes,
        quality: result.quality,
        createdAt: DateTime.now(),
      ),
    );
    if (!context.mounted) return;
    AppSnackbar.success(context, context.l10n.dashboardLogSleepSuccess);
    await ref.read(dashboardControllerProvider.notifier).refresh();
  }

  /// Logs a manually counted step total (and date) for the user.
  static Future<void> showLogSteps(
    BuildContext context,
    WidgetRef ref,
    String userId,
  ) async {
    final _StepsResult? result = await showModalBottomSheet<_StepsResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _LogStepsSheet(),
    );
    if (result == null || result.steps <= 0 || !context.mounted) return;

    await ref.read(stepLogRepositoryProvider).insert(
      StepLog(
        userId: userId,
        stepDate: result.date,
        steps: result.steps,
        distanceKm: StepEstimator.distanceKm(result.steps),
        caloriesBurned: StepEstimator.caloriesBurned(result.steps),
        createdAt: DateTime.now(),
      ),
    );
    if (!context.mounted) return;
    AppSnackbar.success(context, context.l10n.dashboardLogStepsSuccess);
    await ref.read(dashboardControllerProvider.notifier).refresh();
  }

  /// Computes a BMI from weight and height, stores it and refreshes.
  static Future<void> showBmiCalculator(
    BuildContext context,
    WidgetRef ref,
    String userId, {
    double? latestWeight,
    double? heightCm,
  }) async {
    final _BmiResult? result = await showModalBottomSheet<_BmiResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BmiCalculatorSheet(
        initialWeight: latestWeight,
        initialHeight: heightCm,
      ),
    );
    if (result == null || !context.mounted) return;

    await ref.read(bmiLogRepositoryProvider).insert(
      BmiLog(
        userId: userId,
        bmi: result.bmi,
        weightKg: result.weightKg,
        heightCm: result.heightCm,
        category: result.category,
        loggedAt: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );
    if (!context.mounted) return;
    AppSnackbar.success(context, context.l10n.dashboardBmiSaved);
    await ref.read(dashboardControllerProvider.notifier).refresh();
  }
}

class _BmiResult {
  const _BmiResult({
    required this.bmi,
    required this.weightKg,
    required this.heightCm,
    required this.category,
  });

  final double bmi;
  final double weightKg;
  final double heightCm;
  final String category;
}

class _SleepResult {
  const _SleepResult({required this.durationMinutes, required this.quality});

  final int durationMinutes;
  final int quality;
}

class _StepsResult {
  const _StepsResult({required this.steps, required this.date});

  final int steps;
  final DateTime date;
}

class _LogSleepSheet extends StatefulWidget {
  const _LogSleepSheet();

  @override
  State<_LogSleepSheet> createState() => _LogSleepSheetState();
}

class _LogSleepSheetState extends State<_LogSleepSheet> {
  static const List<int> _presets = <int>[360, 420, 480, 540, 600];
  final TextEditingController _controller = TextEditingController();
  int _duration = 480;
  int _quality = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _label(int minutes) {
    final int hours = minutes ~/ 60;
    final int rest = minutes % 60;
    final String h = context.l10n.dashboardSleepHour;
    final String m = context.l10n.dashboardSleepMinute;
    return '${'$hours$h'.toBanglaDigits()} ${'$rest$m'.toBanglaDigits()}';
  }

  void _submit() {
    final int? custom = int.tryParse(_controller.text);
    if (custom != null && custom > 0) _duration = custom;
    if (_duration <= 0) {
      AppSnackbar.info(context, context.l10n.formFieldInvalid);
      return;
    }
    Navigator.of(context).pop(
      _SleepResult(durationMinutes: _duration, quality: _quality),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: context.l10n.dashboardLogSleepTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.dashboardLogSleepHint,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final int preset in _presets)
                ActionChip(
                  avatar: const Icon(Icons.bedtime_rounded, size: 16),
                  label: Text(_label(preset)),
                  onPressed: () =>
                      setState(() => _duration = preset),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    hintText: context.l10n.dashboardLogSleepCustomHint,
                    suffixText: context.l10n.dashboardSleepMinute,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                onPressed: _submit,
                label: context.l10n.commonSave,
                size: AppButtonSize.small,
                fullWidth: false,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              const Icon(Icons.star_rounded, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Slider(
                  value: _quality.toDouble(),
                  max: 5,
                  divisions: 5,
                  label: '$_quality/5',
                  onChanged: (double value) =>
                      setState(() => _quality = value.round()),
                ),
              ),
              Text(
                '$_quality/5'.toBanglaDigits(),
                style: context.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogStepsSheet extends StatefulWidget {
  const _LogStepsSheet();

  @override
  State<_LogStepsSheet> createState() => _LogStepsSheetState();
}

class _LogStepsSheetState extends State<_LogStepsSheet> {
  final TextEditingController _controller = TextEditingController();
  late DateTime _date = DateTime.now();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() {
        _date = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  void _submit() {
    final int? steps = int.tryParse(_controller.text);
    if (steps == null || steps <= 0) {
      AppSnackbar.info(context, context.l10n.formFieldInvalid);
      return;
    }
    Navigator.of(context).pop(_StepsResult(steps: steps, date: _date));
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: context.l10n.dashboardLogStepsTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.dashboardLogStepsHint,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              hintText: '8000',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event_rounded, size: 18),
            label: Text(
              formatLocalizedDate(_date, context.l10n),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            onPressed: _submit,
            label: context.l10n.commonSave,
            icon: Icons.check_rounded,
          ),
        ],
      ),
    );
  }
}

class _SheetScaffold extends StatelessWidget {
  const _SheetScaffold({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.colorScheme.outlineVariant,
                      borderRadius: AppRadius.pillRadius,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  title,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogWaterSheet extends StatefulWidget {
  const _LogWaterSheet();

  @override
  State<_LogWaterSheet> createState() => _LogWaterSheetState();
}

class _LogWaterSheetState extends State<_LogWaterSheet> {
  static const List<int> _presets = <int>[250, 500, 750, 1000, 1500, 2000];
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(int amount) {
    if (amount <= 0) return;
    Navigator.of(context).pop(amount);
  }

  void _submitCustom() {
    final int? amount = int.tryParse(_controller.text);
    if (amount == null || amount <= 0) {
      AppSnackbar.info(context, context.l10n.formFieldInvalid);
      return;
    }
    _submit(amount);
  }

  @override
  Widget build(BuildContext context) {
    final String l10nMl = context.l10n.dashboardMlUnit;

    return _SheetScaffold(
      title: context.l10n.dashboardLogWaterTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.dashboardLogWaterHint,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final int preset in _presets)
                ActionChip(
                  avatar: const Icon(Icons.water_drop_rounded, size: 16),
                  label: Text('$preset $l10nMl'.toBanglaDigits()),
                  onPressed: () => _submit(preset),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    hintText: '750',
                    suffixText: l10nMl,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                onPressed: _submitCustom,
                label: context.l10n.commonAdd,
                size: AppButtonSize.small,
                fullWidth: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogWeightSheet extends StatefulWidget {
  const _LogWeightSheet();

  @override
  State<_LogWeightSheet> createState() => _LogWeightSheetState();
}

class _LogWeightSheetState extends State<_LogWeightSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final double? weight = double.tryParse(_controller.text);
    if (weight == null || weight <= 0) {
      AppSnackbar.info(context, context.l10n.formFieldInvalid);
      return;
    }
    Navigator.of(context).pop(weight);
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: context.l10n.dashboardLogWeightTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              hintText: '72.5',
              suffixText: context.l10n.dashboardKgUnit,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            onPressed: _submit,
            label: context.l10n.commonSave,
            icon: Icons.check_rounded,
          ),
        ],
      ),
    );
  }
}

class _BmiCalculatorSheet extends StatefulWidget {
  const _BmiCalculatorSheet({this.initialWeight, this.initialHeight});

  final double? initialWeight;
  final double? initialHeight;

  @override
  State<_BmiCalculatorSheet> createState() => _BmiCalculatorSheetState();
}

class _BmiCalculatorSheetState extends State<_BmiCalculatorSheet> {
  late final TextEditingController _weightController = TextEditingController(
    text: widget.initialWeight == null
        ? ''
        : widget.initialWeight!.toStringAsFixed(1),
  );
  late final TextEditingController _heightController = TextEditingController(
    text: widget.initialHeight == null
        ? ''
        : widget.initialHeight!.toStringAsFixed(1),
  );

  double? _weight;
  double? _height;

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  double? get _bmi {
    final double? weight = _weight;
    final double? height = _height;
    if (weight == null || height == null || height <= 0) return null;
    final double meters = height / 100;
    return weight / (meters * meters);
  }

  void _onChanged() {
    setState(() {
      _weight = double.tryParse(_weightController.text);
      _height = double.tryParse(_heightController.text);
    });
  }

  String _category(double bmi) {
    if (bmi < 18.5) return context.l10n.bmiUnderweight;
    if (bmi < 25) return context.l10n.bmiNormal;
    if (bmi < 30) return context.l10n.bmiOverweight;
    return context.l10n.bmiObese;
  }

  void _submit() {
    final double? bmi = _bmi;
    if (bmi == null) {
      AppSnackbar.info(context, context.l10n.formFieldInvalid);
      return;
    }
    Navigator.of(context).pop(
      _BmiResult(
        bmi: bmi,
        weightKg: _weight!,
        heightCm: _height!,
        category: _category(bmi),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double? bmi = _bmi;

    return _SheetScaffold(
      title: context.l10n.dashboardBmiTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onChanged: (_) => _onChanged(),
                  decoration: InputDecoration(
                    labelText: context.l10n.dashboardWeightKg,
                    hintText: '72.5',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  onChanged: (_) => _onChanged(),
                  decoration: InputDecoration(
                    labelText: context.l10n.dashboardHeightCm,
                    hintText: '175',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (bmi != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.colorScheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: AppRadius.mdRadius,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calculate_rounded,
                    color: context.colorScheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${context.l10n.dashboardBmiResult}: ${bmi.toStringAsFixed(1)}'.toBanglaDigits(),
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          _category(bmi),
                          style: context.textTheme.bodySmall?.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              context.l10n.formFieldInvalid,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            onPressed: _submit,
            label: context.l10n.commonSave,
            icon: Icons.check_rounded,
          ),
        ],
      ),
    );
  }
}
