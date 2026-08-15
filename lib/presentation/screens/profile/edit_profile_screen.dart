import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/release_logger.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/fields/app_text_field.dart';
import '../../../core/widgets/layout/custom_app_bar.dart';
import '../../../domain/entities/common_enums.dart';
import '../../../domain/entities/profile_data.dart';
import '../../../domain/entities/user_profile.dart';
import '../../providers/locale_provider.dart';
import '../../providers/profile_providers.dart';
import 'profile_labels.dart';
import 'widgets/profile_avatar.dart';

/// Beautiful edit form for every editable profile field.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  late final TextEditingController _targetWeightController;
  late final TextEditingController _countryController;
  late final TextEditingController _timezoneController;

  DateTime? _birthDate;
  Gender? _gender;
  GoalType? _goal;
  ActivityLevel? _activity;
  String? _language;
  String? _photoPath;
  bool _photoRemoved = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final ProfileData? data = ref.read(profileControllerProvider).valueOrNull;
    final UserProfile? profile = data?.profile;

    _nameController = TextEditingController(
      text: data?.user.displayName ?? '',
    );
    _heightController = TextEditingController(
      text: profile?.heightCm == null
          ? ''
          : profile!.heightCm!.toStringAsFixed(0),
    );
    _weightController = TextEditingController(
      text: profile?.weightKg == null
          ? ''
          : profile!.weightKg!.toStringAsFixed(1),
    );
    _targetWeightController = TextEditingController(
      text: profile?.targetWeightKg == null
          ? ''
          : profile!.targetWeightKg!.toStringAsFixed(1),
    );
    _countryController = TextEditingController(text: profile?.country ?? '');
    _timezoneController = TextEditingController(
      text: profile?.timezone ?? _deviceTimezoneLabel(),
    );

    _birthDate = profile?.birthDate;
    _gender = profile?.gender;
    _goal = profile?.fitnessGoal;
    _activity = profile?.activityLevel;
    _language = ref.read(localeProvider).languageCode;
    _photoPath = profile?.photoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _countryController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  double? _parse(String text) => double.tryParse(text.trim());

  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 120),
      lastDate: now,
      helpText: context.l10n.editDateOfBirth,
    );
    if (picked == null) return;
    setState(() => _birthDate = picked);
  }

  Future<void> _changePhoto() async {
    final String? action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) => _PhotoActionSheet(
        hasPhoto: _photoPath != null,
      ),
    );
    if (action == null || !mounted) return;

    final l10n = context.l10n;
    try {
      switch (action) {
        case 'camera':
        case 'gallery':
          final String? path = await ref
              .read(profileControllerProvider.notifier)
              .updatePhoto(
                source: action == 'camera'
                    ? ImageSource.camera
                    : ImageSource.gallery,
              );
          if (path == null) return;
          setState(() {
            _photoPath = path;
            _photoRemoved = false;
          });
          break;
        case 'remove':
          await ref.read(profileControllerProvider.notifier).removePhoto();
          if (!mounted) return;
          setState(() {
            _photoPath = null;
            _photoRemoved = true;
          });
          AppSnackbar.info(context, l10n.profilePhotoRemoved);
          break;
      }
    } catch (error, stackTrace) {
      devLog('Profile photo change failed: $error', error: error, stackTrace: stackTrace);
      if (mounted) AppSnackbar.error(context, l10n.profilePhotoError);
    }
  }

  Future<void> _save() async {
    context.dismissKeyboard();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final l10n = context.l10n;
    try {
      final ProfileController controller =
          ref.read(profileControllerProvider.notifier);

      await controller.updateProfile(
        name: _nameController.text,
        birthDate: _birthDate,
        gender: _gender,
        heightCm: _parse(_heightController.text),
        weightKg: _parse(_weightController.text),
        targetWeightKg: _parse(_targetWeightController.text),
        fitnessGoal: _goal,
        activityLevel: _activity,
        country: _countryController.text.trim().isEmpty
            ? null
            : _countryController.text.trim(),
        language: _language,
        timezone: _timezoneController.text.trim().isEmpty
            ? null
            : _timezoneController.text.trim(),
        photoPath: _photoRemoved ? null : _photoPath,
      );

      final String? language = _language;
      if (language != null &&
          language != ref.read(localeProvider).languageCode) {
        await ref
            .read(localeProvider.notifier)
            .setLocale(Locale(language));
      }

      if (!mounted) return;
      AppSnackbar.success(context, l10n.editProfileSaved);
      context.pop();
    } catch (error, stackTrace) {
      devLog('Profile save failed: $error', error: error, stackTrace: stackTrace);
      if (mounted) AppSnackbar.error(context, l10n.commonError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateHeight(String? value) {
    if (Validators.validateRequired(value, requiredError: context.l10n.formFieldRequired) != null) {
      return context.l10n.formFieldRequired;
    }
    final double? parsed = _parse(value ?? '');
    if (parsed == null || parsed < 60 || parsed > 250) {
      return context.l10n.profileHeightInvalid;
    }
    return null;
  }

  String? _validateWeight(String? value) {
    if (Validators.validateRequired(value, requiredError: context.l10n.formFieldRequired) != null) {
      return context.l10n.formFieldRequired;
    }
    final double? parsed = _parse(value ?? '');
    if (parsed == null || parsed < 20 || parsed > 400) {
      return context.l10n.profileWeightInvalid;
    }
    return null;
  }

  String? _validateTargetWeight(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final double? parsed = _parse(text);
    if (parsed == null || parsed < 20 || parsed > 400) {
      return context.l10n.profileTargetWeightInvalid;
    }
    return null;
  }

  /// The device's current UTC offset, e.g. `UTC+06:00`, used as a sensible
  /// default when the profile has no timezone stored yet.
  String _deviceTimezoneLabel() {
    final Duration offset = DateTime.now().timeZoneOffset;
    final String sign = offset.isNegative ? '-' : '+';
    final Duration abs = offset.abs();
    final String hh = abs.inHours.toString().padLeft(2, '0');
    final String mm = (abs.inMinutes % 60).toString().padLeft(2, '0');
    return 'UTC$sign$hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: CustomAppBar(
        title: l10n.editProfileTitle,
        showBackButton: true,
        glass: true,
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PhotoPicker(
                        photoPath: _photoPath,
                        networkUrl: ref
                            .read(profileControllerProvider)
                            .valueOrNull
                            ?.user
                            .photoUrl,
                        name: _nameController.text,
                        onTap: _changePhoto,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        l10n.editProfilePhoto,
                        style: context.textTheme.labelLarge?.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        l10n.editTakePhoto,
                        style: context.textTheme.labelMedium?.copyWith(
                          color: context.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: _nameController,
                        label: l10n.editName,
                        hintText: l10n.editNameHint,
                        prefixIcon: Icons.person_rounded,
                        textCapitalization: TextCapitalization.words,
                        enabled: !_saving,
                        validator: (String? value) => Validators.validateName(
                          value,
                          requiredError: l10n.profileNameRequired,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _countryController,
                        label: l10n.editCountry,
                        hintText: l10n.editCountryHint,
                        prefixIcon: Icons.public_rounded,
                        textCapitalization: TextCapitalization.words,
                        enabled: !_saving,
                        validator: (String? value) {
                          if ((value ?? '').trim().length > 60) {
                            return l10n.profileCountryInvalid;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _DateOfBirthField(
                        birthDate: _birthDate,
                        onTap: _pickDate,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _SectionLabel(
                        icon: Icons.wc_rounded,
                        label: l10n.editSelectGender,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SegmentedButton<Gender>(
                        segments: [
                          for (final Gender gender in Gender.values)
                            ButtonSegment<Gender>(
                              value: gender,
                              label: Text(
                                ProfileLabels.gender(l10n, gender),
                              ),
                              icon: Icon(
                                switch (gender) {
                                  Gender.male => Icons.male_rounded,
                                  Gender.female => Icons.female_rounded,
                                  Gender.other => Icons.transgender_rounded,
                                },
                              ),
                            ),
                        ],
                        selected: {?_gender},
                        onSelectionChanged: _saving
                            ? null
                            : (Set<Gender> selection) => setState(
                                () => _gender = selection.first,
                              ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _heightController,
                              label: l10n.editHeightCm,
                              prefixIcon: Icons.height_rounded,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              enabled: !_saving,
                              validator: _validateHeight,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: AppTextField(
                              controller: _weightController,
                              label: l10n.editWeightKg,
                              prefixIcon: Icons.monitor_weight_rounded,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              enabled: !_saving,
                              validator: _validateWeight,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _targetWeightController,
                        label: l10n.editTargetWeightKg,
                        prefixIcon: Icons.flag_rounded,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        enabled: !_saving,
                        validator: _validateTargetWeight,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _SectionLabel(
                        icon: Icons.track_changes_rounded,
                        label: l10n.profileFitnessGoal,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _ChoiceWrap<GoalType>(
                        values: const <GoalType>[
                          GoalType.weightLoss,
                          GoalType.weightGain,
                          GoalType.maintainWeight,
                          GoalType.muscleBuilding,
                          GoalType.generalFitness,
                        ],
                        selected: _goal,
                        labelOf: (GoalType value) =>
                            ProfileLabels.goal(l10n, value),
                        onSelected: _saving
                            ? null
                            : (GoalType value) =>
                                setState(() => _goal = value),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _SectionLabel(
                        icon: Icons.directions_run_rounded,
                        label: l10n.profileActivityLevel,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _ChoiceWrap<ActivityLevel>(
                        values: const <ActivityLevel>[
                          ActivityLevel.sedentary,
                          ActivityLevel.light,
                          ActivityLevel.moderate,
                          ActivityLevel.active,
                          ActivityLevel.athlete,
                        ],
                        selected: _activity,
                        labelOf: (ActivityLevel value) =>
                            ProfileLabels.activity(l10n, value),
                        onSelected: _saving
                            ? null
                            : (ActivityLevel value) =>
                                setState(() => _activity = value),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _SectionLabel(
                        icon: Icons.language_rounded,
                        label: l10n.editLanguage,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _LanguageSelector(
                        selected: _language,
                        enabled: !_saving,
                        onChanged: (String? code) =>
                            setState(() => _language = code),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _SectionLabel(
                        icon: Icons.schedule_rounded,
                        label: l10n.editTimezone,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      AppTextField(
                        controller: _timezoneController,
                        label: l10n.editTimezone,
                        hintText: l10n.editTimezoneHint,
                        prefixIcon: Icons.schedule_rounded,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      AppButton(
                        onPressed: _saving ? null : _save,
                        label: l10n.commonSave,
                        icon: Icons.check_rounded,
                        isLoading: _saving,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.photoPath,
    required this.networkUrl,
    required this.name,
    required this.onTap,
  });

  final String? photoPath;
  final String? networkUrl;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              ProfileAvatar(
                photoPath: photoPath,
                networkUrl: networkUrl,
                name: name,
                radius: 56,
              ),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colorScheme.primary,
                    border: Border.all(
                      color: context.colorScheme.surface,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    Icons.photo_camera_rounded,
                    size: 18,
                    color: context.colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text(context.l10n.editChangePhoto),
          ),
        ],
      ),
    );
  }
}

class _PhotoActionSheet extends StatelessWidget {
  const _PhotoActionSheet({required this.hasPhoto});

  final bool hasPhoto;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: context.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.photo_camera_rounded,
                color: context.colorScheme.primary,
              ),
              title: Text(l10n.editTakePhoto),
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.photo_library_rounded,
                color: context.colorScheme.primary,
              ),
              title: Text(l10n.editChooseFromGallery),
              onTap: () => Navigator.of(context).pop('gallery'),
            ),
            if (hasPhoto)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_forever_rounded,
                  color: context.colorScheme.error,
                ),
                title: Text(
                  l10n.editRemovePhoto,
                  style: TextStyle(color: context.colorScheme.error),
                ),
                onTap: () => Navigator.of(context).pop('remove'),
              ),
          ],
        ),
      ),
    );
  }
}

class _DateOfBirthField extends StatelessWidget {
  const _DateOfBirthField({required this.birthDate, required this.onTap});

  final DateTime? birthDate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String label = birthDate == null
        ? context.l10n.editDateOfBirth
        : DateFormat('d MMMM yyyy').format(birthDate!);
    final bool hasValue = birthDate != null;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.lg,
        ),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest,
          borderRadius: AppRadius.mdRadius,
          border: Border.all(
            color: hasValue
                ? context.colorScheme.primary.withValues(alpha: 0.6)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.cake_rounded,
              color: hasValue
                  ? context.colorScheme.primary
                  : context.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: context.textTheme.bodyLarge?.copyWith(
                  color: hasValue
                      ? context.colorScheme.onSurface
                      : context.colorScheme.onSurfaceVariant,
                  fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            const Icon(Icons.event_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: context.colorScheme.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ChoiceWrap<T> extends StatelessWidget {
  const _ChoiceWrap({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> values;
  final T? selected;
  final String Function(T) labelOf;
  final ValueChanged<T>? onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final T value in values)
          ChoiceChip(
            label: Text(labelOf(value)),
            selected: selected == value,
            onSelected: onSelected == null
                ? null
                : (_) => onSelected!(value),
            showCheckmark: true,
            avatar: Icon(
              selected == value
                  ? Icons.check_rounded
                  : Icons.circle_outlined,
              size: 16,
            ),
          ),
      ],
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadius.mdRadius,
        border: Border.all(
          color: selected != null
              ? context.colorScheme.primary.withValues(alpha: 0.6)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          borderRadius: AppRadius.mdRadius,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          hint: Text(context.l10n.editLanguage),
          items: const [
            DropdownMenuItem(value: 'bn', child: Text('বাংলা')),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}
