import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/string_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../providers/settings_providers.dart';
import 'widgets/pin_ui.dart';

enum _PinPhase { current, enter, confirm }

/// Creates or changes the app-lock PIN.
///
/// When [requireCurrent] is true the user must first enter the existing PIN
/// before a new one can be set. Always demands a matching confirmation.
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key, this.requireCurrent = false});

  final bool requireCurrent;

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  static const int _pinLength = 4;

  late _PinPhase _phase;
  String? _enteredPin;
  String _current = '';
  bool _error = false;
  bool _saving = false;
  Timer? _errorTimer;

  @override
  void initState() {
    super.initState();
    _phase = widget.requireCurrent ? _PinPhase.current : _PinPhase.enter;
  }

  @override
  void dispose() {
    _errorTimer?.cancel();
    super.dispose();
  }

  bool get _isCurrent => _phase == _PinPhase.current;

  void _onDigit(String digit) {
    if (_saving) return;
    if (_current.length >= _pinLength) return;
    setState(() {
      _current += digit;
      _error = false;
    });
    if (_current.length == _pinLength) {
      _advance();
    }
  }

  void _onBackspace() {
    if (_current.isEmpty || _saving) return;
    setState(() {
      _current = _current.substring(0, _current.length - 1);
      _error = false;
    });
  }

  Future<void> _advance() async {
    switch (_phase) {
      case _PinPhase.current:
        final bool ok = await ref
            .read(settingsControllerProvider.notifier)
            .verifyPin(_current);
        if (!mounted) return;
        if (ok) {
          setState(() {
            _phase = _PinPhase.enter;
            _current = '';
          });
        } else {
          _fail();
        }
      case _PinPhase.enter:
        _enteredPin = _current;
        setState(() {
          _phase = _PinPhase.confirm;
          _current = '';
        });
      case _PinPhase.confirm:
        if (_current == _enteredPin) {
          await _save();
        } else {
          _enteredPin = null;
          _fail(confirmMismatch: true);
          if (mounted) {
            setState(() => _phase = _PinPhase.enter);
          }
        }
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final String pin = _current;
    await ref.read(settingsControllerProvider.notifier).setPin(pin);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _fail({bool confirmMismatch = false}) {
    setState(() {
      _error = true;
      _current = '';
    });
    _errorTimer?.cancel();
    _errorTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _error = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final (String title, String subtitle) = switch (_phase) {
      _PinPhase.current => (
        context.l10n.settingsPinCurrent,
        context.l10n.settingsPinCurrentSubtitle,
      ),
      _PinPhase.enter => (
        context.l10n.settingsPinSetupTitle,
        context.l10n.settingsPinSetupSubtitle,
      ),
      _PinPhase.confirm => (
        context.l10n.settingsPinConfirm,
        context.l10n.settingsPinConfirmSubtitle,
      ),
    };

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.settingsPinLock)),
      body: SafeArea(
        child: Column(
          children: [
            AppSpacing.xl.heightSpace,
            Icon(
              Icons.lock_rounded,
              size: 56,
              color: scheme.primary,
            ),
            AppSpacing.lg.heightSpace,
            Text(
              title,
              style: context.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            AppSpacing.xs.heightSpace,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            AppSpacing.lg.heightSpace,
            PinDots(
              length: _pinLength,
              entered: _current.length,
              error: _error,
            ),
            AppSpacing.xs.heightSpace,
            if (_error)
              Text(
                _isCurrent
                    ? context.l10n.settingsPinIncorrect
                    : context.l10n.settingsPinMismatch,
                style: context.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const Spacer(),
            PinPad(onDigit: _onDigit, onBackspace: _onBackspace),
            AppSpacing.xxl.heightSpace,
          ],
        ),
      ),
    );
  }
}
