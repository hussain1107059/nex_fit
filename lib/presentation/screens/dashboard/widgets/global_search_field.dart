import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../providers/dashboard_providers.dart';

/// Debounced search field driving the dashboard global search.
class GlobalSearchField extends ConsumerStatefulWidget {
  const GlobalSearchField({super.key});

  @override
  ConsumerState<GlobalSearchField> createState() => _GlobalSearchFieldState();
}

class _GlobalSearchFieldState extends ConsumerState<GlobalSearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(AppConstants.debounceDuration, () {
      if (mounted) {
        ref.read(searchQueryProvider.notifier).state = value.trim();
      }
    });
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: context.l10n.dashboardSearchHint,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          onPressed: _clear,
          icon: const Icon(Icons.close_rounded, size: 18),
          tooltip: context.l10n.commonClose,
        ),
      ),
    );
  }
}
