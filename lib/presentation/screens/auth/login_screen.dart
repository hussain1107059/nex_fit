import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/utils/result.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/widgets/fields/app_text_field.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_user.dart';
import '../../../injection/dependency_injection.dart';
import '../../providers/auth_controller.dart';
import '../../router/app_router.dart';
import '../../widgets/auth/auth_layout.dart';
import '../../widgets/auth/auth_logo_header.dart';

/// Email/password sign-in screen.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _rememberMe = true;

  bool get _isBusy => ref.watch(authControllerProvider).isBusy;

  @override
  void initState() {
    super.initState();
    _rememberMe = ref.read(appPreferencesRepositoryProvider).getRememberMe();
  }

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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    context.dismissKeyboard();
    if (!_formKey.currentState!.validate()) return;

    final Result<AppUser> result = await ref
        .read(authControllerProvider.notifier)
        .signInWithEmail(
          email: _emailController.text,
          password: _passwordController.text,
          rememberMe: _rememberMe,
        );
    if (!mounted || result.isFailure) return;
    final AppUser user = result.valueOrNull!;
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
          Text(l10n.authNoAccount, style: context.textTheme.bodyMedium),
          TextButton(
            onPressed: busy ? null : () => context.go(AppRoutes.register),
            child: Text(l10n.authCreateAccount),
          ),
        ],
      ),
      children: [
        AuthLogoHeader(
          title: l10n.authSignInTitle,
          subtitle: l10n.authSignInSubtitle,
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                textInputAction: TextInputAction.done,
                enabled: !busy,
                onFieldSubmitted: (_) => busy ? null : _submit(),
                validator: (String? value) => Validators.validateRequired(
                  value,
                  requiredError: l10n.authPasswordRequired,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: busy
                          ? null
                          : () => setState(() => _rememberMe = !_rememberMe),
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            onChanged: busy
                                ? null
                                : (bool? value) => setState(
                                    () => _rememberMe = value ?? false,
                                  ),
                          ),
                          Expanded(
                            child: Text(
                              l10n.authRememberMe,
                              style: context.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => context.go(AppRoutes.forgotPassword),
                    child: Text(l10n.authForgotPassword),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          onPressed: busy ? null : _submit,
          label: l10n.authSignIn,
          icon: Icons.login_rounded,
          isLoading: busy,
        ),
      ],
    );
  }
}
