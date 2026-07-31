import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/failure.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/failure_message.dart';
import '../../../core/utils/result.dart';
import '../../../core/widgets/buttons/app_button.dart';
import '../../../core/widgets/dialogs/app_dialog.dart';
import '../../../core/widgets/feedback/app_snackbar.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/app_user.dart';
import '../../providers/auth_controller.dart';
import '../../providers/auth_provider.dart';
import '../../router/app_router.dart';
import '../../widgets/auth/auth_layout.dart';
import '../../widgets/auth/auth_logo_header.dart';

/// Blocks the user from entering the app until their email is verified.
/// Offers resend + refresh actions.
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  _VerificationAction _action = _VerificationAction.none;

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

  Future<void> _resend() async {
    setState(() => _action = _VerificationAction.resend);
    final Result<void> result =
        await ref.read(authControllerProvider.notifier).sendVerificationEmail();
    if (!mounted) return;
    setState(() => _action = _VerificationAction.none);
    if (result.isFailure) return;
    AppSnackbar.success(context, context.l10n.authVerificationSent);
  }

  Future<void> _refreshStatus() async {
    setState(() => _action = _VerificationAction.refresh);
    final Result<AppUser?> result = await ref
        .read(authControllerProvider.notifier)
        .refreshVerificationStatus();
    if (!mounted) return;
    setState(() => _action = _VerificationAction.none);

    if (result.isFailure) return;
    final AppUser? user = result.valueOrNull;
    if (user != null && user.isEmailVerified) {
      await AppDialog.success(
        context: context,
        title: context.l10n.authEmailVerified,
        okLabel: context.l10n.commonContinue,
      );
      if (!mounted) return;
      context.go(AppRoutes.shell);
    } else {
      AppSnackbar.info(context, context.l10n.authVerificationNotYet);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (!mounted) return;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    _listenForFailures();
    final l10n = context.l10n;
    final AppUser? user = ref.watch(currentUserProvider);
    final bool signedIn = user != null && user.isSignedIn;
    final bool busy = _isBusy;

    if (!signedIn) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return AuthLayout(
      showBackButton: false,
      children: [
        AuthLogoHeader(
          title: l10n.authEmailVerificationTitle,
          subtitle: l10n.authEmailVerificationSubtitle,
        ),
        const SizedBox(height: AppSpacing.xxxl),
        Container(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.6,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            children: [
              Icon(
                Icons.mark_email_unread_rounded,
                size: 72,
                color: context.colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l10n.authEmailVerificationSentTo,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                user.email ?? '',
                textAlign: TextAlign.center,
                style: context.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: context.colorScheme.errorContainer.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(AppSpacing.lg),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 18,
                      color: context.colorScheme.error,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      l10n.authEmailNotVerified,
                      style: context.textTheme.labelMedium?.copyWith(
                        color: context.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
        AppButton(
          onPressed: busy ? null : _resend,
          label: l10n.authResendEmail,
          icon: Icons.send_rounded,
          variant: AppButtonVariant.outline,
          isLoading: _action == _VerificationAction.resend,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          onPressed: busy ? null : _refreshStatus,
          label: l10n.authRefreshStatus,
          icon: Icons.refresh_rounded,
          isLoading: _action == _VerificationAction.refresh,
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: busy ? null : _signOut,
          child: Text(l10n.authSignOut),
        ),
      ],
    );
  }
}

enum _VerificationAction { none, resend, refresh }
