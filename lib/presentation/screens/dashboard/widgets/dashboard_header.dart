import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/extensions/string_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../domain/entities/app_user.dart';
import 'global_search_field.dart';

/// Greeting, user name, today's date and the global search field.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({super.key, required this.user});

  final AppUser user;

  String _greeting(BuildContext context, DateTime now) {
    final int hour = now.hour;
    final String greeting = switch (hour) {
      < 12 => context.l10n.dashboardGreetingMorning,
      < 17 => context.l10n.dashboardGreetingAfternoon,
      _ => context.l10n.dashboardGreetingEvening,
    };
    return greeting;
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final String name = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : context.l10n.commonProfile;
    final String date = DateFormat('d MMMM yyyy')
        .format(now)
        .toBanglaDigits();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_greeting(context, now)},',
                    style: context.textTheme.titleMedium?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            _DashboardAvatar(user: user),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 14,
              color: context.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              date,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const GlobalSearchField(),
      ],
    );
  }
}

class _DashboardAvatar extends StatelessWidget {
  const _DashboardAvatar({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final String? photo = user.photoUrl;
    if (photo != null && photo.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundColor: scheme.primaryContainer,
        child: ClipOval(
          child: Image.network(
            photo,
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _InitialAvatar(user: user),
          ),
        ),
      );
    }
    return _InitialAvatar(user: user);
  }
}

class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = context.colorScheme;
    final String source = user.displayName ?? user.email ?? '?';
    final String initial = source.trim().isEmpty
        ? '?'
        : source.trim()[0].toUpperCase();

    return CircleAvatar(
      radius: 24,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        initial,
        style: context.textTheme.titleLarge?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
