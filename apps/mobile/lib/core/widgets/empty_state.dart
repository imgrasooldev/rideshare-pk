import 'package:flutter/material.dart';

/// Friendly empty/error state: soft icon medallion, title, message, optional CTA.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = isError ? theme.colorScheme.error : theme.colorScheme.primary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tint.withValues(alpha: 0.1),
              ),
              child: Icon(icon, size: 34, color: tint),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
