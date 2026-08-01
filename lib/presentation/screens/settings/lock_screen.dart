import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../injection/dependency_injection.dart';
import '../../providers/settings_providers.dart';
import 'widgets/pin_ui.dart';

/// Full-screen gate shown when the app lock is active. Requires the correct
/// PIN (or a successful biometric prompt when enabled) before the app is
/// revealed again.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  static const int _pinLength = 4;

  final List<String> _entered = <String>[];
  bool _error = false;
  bool _checking = false;
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryBiometric());
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    super.dispose();
  }

  Future<void> _tryBiometric() async {
    final settings = ref.read(settingsControllerProvider).valueOrNull;
    final bool biometricEnabled = settings?.biometricEnabled ?? false;
    if (!biometricEnabled) return;
    final bool supported = await ref.read(biometricAvailableProvider.future);
    if (!supported || !mounted) return;
    final bool ok = await ref
        .read(appSecurityServiceProvider)
        .authenticate(reason: context.l10n.settingsLockSubtitle);
    if (ok && mounted) {
      await ref.read(appLockProvider.notifier).unlock();
    }
  }

  void _onDigit(String digit) {
    if (_checking) return;
    if (_entered.length >= _pinLength) return;
    setState(() {
      _entered.add(digit);
      _error = false;
    });
    if (_entered.length == _pinLength) {
      _verify();
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty || _checking) return;
    setState(() {
      _entered.removeLast();
      _error = false;
    });
  }

  Future<void> _verify() async {
    setState(() => _checking = true);
    final String pin = _entered.join();
    final bool ok = await ref
        .read(settingsControllerProvider.notifier)
        .verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      await ref.read(appLockProvider.notifier).unlock();
      return;
    }
    setState(() {
      _checking = false;
      _error = true;
    });
    _errorTimer?.cancel();
    _errorTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _entered.clear();
        _error = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final bool biometricEnabled =
        ref.watch(settingsControllerProvider).valueOrNull?.biometricEnabled ??
        false;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surface,
              scheme.surface,
              scheme.primaryContainer.withValues(alpha: 0.3),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppSpacing.xxxl.heightSpace,
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: scheme.primaryContainer.withValues(alpha: 0.5),
                ),
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: SvgPicture.asset(AppAssets.logo, fit: BoxFit.contain),
              ),
              AppSpacing.xl.heightSpace,
              Text(
                context.l10n.settingsLockTitle,
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              AppSpacing.xs.heightSpace,
              Text(
                context.l10n.settingsLockSubtitle,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              AppSpacing.xl.heightSpace,
              PinDots(
                length: _pinLength,
                entered: _entered.length,
                error: _error,
              ),
              AppSpacing.xs.heightSpace,
              if (_error)
                Text(
                  context.l10n.settingsPinIncorrect,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const Spacer(),
              PinPad(
                onDigit: _onDigit,
                onBackspace: _onBackspace,
                onBiometric: _tryBiometric,
                biometricAvailable: biometricEnabled,
              ),
              AppSpacing.xxl.heightSpace,
            ],
          ),
        ),
      ),
    );
  }
}
