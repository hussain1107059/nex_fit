import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failure.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/dialogs/app_dialog.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/fields/app_text_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_user.dart';
import '../../providers/auth_controller.dart';
import '../../router/app_router.dart';
import '../../widgets/auth/auth_layout.dart';
import '../../widgets/auth/auth_logo_header.dart';
import '../../widgets/auth/password_strength_bar.dart';

/// Email & password registration screen.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool get _isBusy => ref.watch(authControllerProvider).isBusy;

  void _listenForFailures() {
    ref.listen<AuthState>(
      authControllerProvider,
      (AuthState? previous, AuthState next) {
        final Failure? failure = next.failure;
        if (failure == null) return;
        if (previous != null && previous.failure == failure) return;
        if (!mounted) return;
        AppSnackbar.error(
          context,
          localizeFailureMessage(context.l10n, failure.message),
        );
      },
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    context.dismissKeyboard();
    if (!_formKey.currentState!.validate()) return;

    final Result<AppUser> result = await ref
        .read(authControllerProvider.notifier)
        .signUpWithEmail(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
        );

    if (!mounted) return;
    if (result.isFailure) {
      // The email is already registered (typically from an earlier sign-up that
      // never completed email verification). Route to the verification/resend
      // screen instead of leaving the user stuck on a dead-end error toast.
      final String? code = result.failureOrNull?.code;
      if (code == 'authEmailInUse') {
        ref.read(authControllerProvider.notifier)
            .rememberPendingVerification(_emailController.text);
        context.go(AppRoutes.emailVerification);
      }
      return;
    }
    final AppUser user = result.valueOrNull!;

    // Offline / already-verified accounts enter the app immediately; newly
    // created online accounts must verify their email first.
    if (user.isEmailVerified) {
      context.go(AppRoutes.destinationFor(user));
      return;
    }

    await AppDialog.success(
      context: context,
      title: context.l10n.authAccountCreated,
      message: context.l10n.authAccountCreatedSubtitle,
    );
    if (!mounted) return;
    context.go(AppRoutes.destinationFor(user));
  }

  @override
  Widget build(BuildContext context) {
    _listenForFailures();
    final l10n = context.l10n;
    final bool busy = _isBusy;

    return AuthLayout(
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              l10n.authHaveAccount,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: busy ? null : () => context.go(AppRoutes.login),
            child: Text(l10n.authSignIn, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      children: [
        AuthLogoHeader(
          title: l10n.authSignUpTitle,
          subtitle: l10n.authSignUpSubtitle,
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _nameController,
                label: l10n.authName,
                hintText: l10n.authNameHint,
                prefixIcon: Icons.person_rounded,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                enabled: !busy,
                validator: (String? value) => Validators.validateName(
                  value,
                  requiredError: l10n.authNameRequired,
                  maxLength: AppConstants.maxNameLength,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _emailController,
                label: l10n.authEmail,
                hintText: l10n.authEmailHint,
                prefixIcon: Icons.alternate_email_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                enabled: !busy,
                validator: (String? value) => Validators.validateEmail(
                  value,
                  requiredError: l10n.authEmailRequired,
                  invalidError: l10n.authEmailInvalid,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _passwordController,
                label: l10n.authPassword,
                prefixIcon: Icons.lock_rounded,
                obscureText: true,
                textInputAction: TextInputAction.next,
                enabled: !busy,
                onChanged: (_) => setState(() {}),
                validator: (String? value) => Validators.validatePassword(
                  value,
                  requiredError: l10n.authPasswordRequired,
                  tooShortError: l10n.authPasswordTooShort,
                  minLength: AppConstants.minPasswordLength,
                ),
              ),
              PasswordStrengthBar(password: _passwordController.text),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _confirmController,
                label: l10n.authConfirmPassword,
                prefixIcon: Icons.lock_rounded,
                obscureText: true,
                textInputAction: TextInputAction.done,
                enabled: !busy,
                onFieldSubmitted: (_) => busy ? null : _submit(),
                validator: (String? value) =>
                    Validators.validateConfirmPassword(
                      value,
                      _passwordController.text,
                      requiredError: l10n.authPasswordRequired,
                      mismatchError: l10n.authPasswordMismatch,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          onPressed: busy ? null : _submit,
          label: l10n.authSignUp,
          icon: Icons.person_add_alt_1_rounded,
          isLoading: busy,
        ),
      ],
    );
  }
}
