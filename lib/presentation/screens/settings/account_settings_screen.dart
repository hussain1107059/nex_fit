import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/dialogs/app_dialog.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/fields/app_text_field.dart';
import '../../providers/auth_controller.dart';
import '../../providers/auth_provider.dart';
import '../profile/widgets/profile_avatar.dart';
import 'widgets/settings_widgets.dart';

/// Account-level controls: the signed-in identity, password change, logout and
/// the destructive delete-account action.
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsAccount)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          Center(
            child: Column(
              children: [
                ProfileAvatar(
                  photoPath: null,
                  networkUrl: user?.photoUrl,
                  name: user?.displayName ?? user?.email ?? '?',
                  radius: 40,
                ),
                AppSpacing.md.heightSpace,
                Text(
                  user?.displayName ?? context.l10n.settingsAccount,
                  textAlign: TextAlign.center,
                  style: context.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (user?.email != null) ...[
                  AppSpacing.xs.heightSpace,
                  Text(
                    user!.email!,
                    textAlign: TextAlign.center,
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          AppSpacing.xl.heightSpace,
          SettingsSectionTitle(context.l10n.settingsAccount),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.password_rounded,
                title: context.l10n.accountChangePassword,
                onTap: () => _changePassword(context, ref),
              ),
            ],
          ),
          SettingsSectionTitle(context.l10n.settingsSecurity),
          SettingsCard(
            children: [
              SettingsTile(
                icon: Icons.logout_rounded,
                title: context.l10n.accountLogout,
                onTap: () => _confirmLogout(context, ref),
              ),
              const Divider(height: 1, indent: AppSpacing.xxl),
              SettingsTile(
                icon: Icons.delete_outline_rounded,
                title: context.l10n.settingsDeleteAccount,
                subtitle: context.l10n.settingsDeleteAccountSubtitle,
                destructive: true,
                onTap: () => _confirmDeleteAccount(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return _ChangePasswordSheet(
          onSubmit: (String newPassword) async {
            final result = await ref
                .read(authControllerProvider.notifier)
                .changePassword(newPassword: newPassword);
            return result;
          },
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await AppDialog.confirm(
      context: context,
      title: context.l10n.accountLogout,
      message: context.l10n.accountLogoutConfirm,
      confirmLabel: context.l10n.accountLogout,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(authControllerProvider.notifier).signOut();
    if (result.isFailure && context.mounted) {
      AppSnackbar.error(context, context.l10n.accountLogoutFailed);
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bool? confirmed = await AppDialog.confirm(
      context: context,
      title: context.l10n.settingsDeleteAccount,
      message: context.l10n.settingsDeleteAccountConfirm,
      confirmLabel: context.l10n.settingsDeleteAccountAction,
      destructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    final result = await ref.read(authControllerProvider.notifier).deleteAccount();
    if (result.isFailure && context.mounted) {
      AppSnackbar.error(context, context.l10n.settingsDeleteAccountFailed);
    }
  }
}

/// Modal bottom sheet with the new-password and confirmation fields.
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet({required this.onSubmit});

  final Future<Result<void>> Function(String newPassword) onSubmit;

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final result = await widget.onSubmit(_newPasswordController.text);

    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.of(context).pop();
      await AppDialog.success(
        context: context,
        title: context.l10n.accountPasswordChangedTitle,
        message: context.l10n.accountPasswordChangedMessage,
      );
    } else {
      setState(() => _submitting = false);
      AppSnackbar.error(context, context.l10n.accountChangePasswordFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.accountChangePassword,
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            AppSpacing.lg.heightSpace,
            AppTextField(
              controller: _newPasswordController,
              label: context.l10n.accountChangePasswordNew,
              hintText: context.l10n.accountChangePasswordHint,
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: true,
              showToggleVisibility: true,
              enabled: !_submitting,
              textInputAction: TextInputAction.next,
              validator: (String? value) {
                final String text = (value ?? '').trim();
                if (text.length < 8) {
                  return context.l10n.accountChangePasswordShort;
                }
                return null;
              },
            ),
            AppSpacing.md.heightSpace,
            AppTextField(
              controller: _confirmController,
              label: context.l10n.accountChangePasswordConfirm,
              prefixIcon: Icons.lock_reset_rounded,
              obscureText: true,
              showToggleVisibility: true,
              enabled: !_submitting,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              validator: (String? value) {
                if ((value ?? '') != _newPasswordController.text) {
                  return context.l10n.accountChangePasswordMismatch;
                }
                return null;
              },
            ),
            AppSpacing.lg.heightSpace,
            AppButton(
              onPressed: _submitting ? null : _submit,
              label: context.l10n.commonSave,
              icon: Icons.check_rounded,
              isLoading: _submitting,
            ),
          ],
        ),
      ),
    );
  }
}