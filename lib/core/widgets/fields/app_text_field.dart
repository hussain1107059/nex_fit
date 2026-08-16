import 'package:flutter/material.dart';

import '../../extensions/context_extensions.dart';

/// Reusable premium text field with label, validation and icon support.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.label,
    this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.none,
    this.errorText,
    this.initialValue,
    this.showToggleVisibility = false,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label;
  final String? hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final bool autofocus;
  final int? maxLength;
  final int minLines;
  final int maxLines;
  final TextCapitalization textCapitalization;
  final String? errorText;
  final String? initialValue;
  final bool showToggleVisibility;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late final TextEditingController _controller;
  bool _obscured = false;

  bool get _isPasswordField => widget.showToggleVisibility || widget.obscureText;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
    _controller = widget.controller ?? TextEditingController();
    if (widget.initialValue != null) {
      _controller.text = widget.initialValue!;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget? suffix = _buildSuffix(context);

    return TextFormField(
      controller: _controller,
      focusNode: widget.focusNode,
      obscureText: _obscured,
      enabled: widget.enabled,
      autofocus: widget.autofocus,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,
      maxLength: widget.maxLength,
      minLines: widget.minLines,
      maxLines: widget.maxLines,
      textCapitalization: widget.textCapitalization,
      style: context.textTheme.bodyLarge,
      cursorColor: context.colorScheme.primary,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hintText,
        errorText: widget.errorText,
        counterText: widget.maxLength != null ? '' : null,
        prefixIcon: widget.prefixIcon != null
            ? Icon(widget.prefixIcon, size: 22)
            : null,
        suffixIcon: suffix,
      ),
    );
  }

  Widget? _buildSuffix(BuildContext context) {
    if (_isPasswordField) {
      return IconButton(
        onPressed: () => setState(() => _obscured = !_obscured),
        tooltip: _obscured
            ? context.l10n.authShowPassword
            : context.l10n.authHidePassword,
        icon: Icon(
          _obscured ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          size: 22,
        ),
      );
    }
    return widget.suffixIcon;
  }
}
