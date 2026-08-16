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
import '../../providers/auth_controller.dart';
import '../../router/app_router.dart';
import '../../widgets/auth/auth_layout.dart';

/// Password reset screen. Switches to a success view after the reset link
/// has been sent.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  bool _sent = false;

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
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    context.dismissKeyboard();
    if (!_formKey.currentState!.validate()) return;

    final Result<void> result = await ref
        .read(authControllerProvider.notifier)
        .resetPassword(email: _emailController.text);

    if (!mounted || result.isFailure) return;
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    _listenForFailures();
    return AuthLayout(
      showBackButton: true,
      onBackPressed: () => context.go(AppRoutes.login),
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                child: child,
              ),
            );
          },
          child: _sent ? _buildSuccess(context) : _buildForm(context),
        ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) {
    final l10n = context.l10n;
    final bool busy = _isBusy;

    return Column(
      key: const ValueKey<bool>(false),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.lock_reset_rounded,
          size: 64,
          color: context.colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.authForgotPasswordTitle,
          textAlign: TextAlign.center,
          style: context.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.authForgotPasswordSubtitle,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Form(
          key: _formKey,
          child: AppTextField(
            controller: _emailController,
            label: l10n.authEmail,
            hintText: l10n.authEmailHint,
            prefixIcon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            enabled: !busy,
            onFieldSubmitted: (_) => busy ? null : _submit(),
            validator: (String? value) => Validators.validateEmail(
              value,
              requiredError: l10n.authEmailRequired,
              invalidError: l10n.authEmailInvalid,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          onPressed: busy ? null : _submit,
          label: l10n.authSendResetLink,
          icon: Icons.send_rounded,
          isLoading: busy,
        ),
      ],
    );
  }

  Widget _buildSuccess(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      key: const ValueKey<bool>(true),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (BuildContext context, double value, Widget? child) {
            return Transform.scale(scale: value, child: child);
          },
          child: CircleAvatar(
            radius: 40,
            backgroundColor: context.colorScheme.primaryContainer,
            child: Icon(
              Icons.mark_email_read_rounded,
              size: 44,
              color: context.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.authResetLinkSent,
          textAlign: TextAlign.center,
          style: context.textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.authResetLinkSentSubtitle,
          textAlign: TextAlign.center,
          style: context.textTheme.bodyMedium?.copyWith(
            color: context.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        AppButton(
          onPressed: () => context.go(AppRoutes.login),
          label: l10n.authBackToLogin,
          icon: Icons.login_rounded,
        ),
      ],
    );
  }
}
