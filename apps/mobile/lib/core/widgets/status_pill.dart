import 'package:flutter/material.dart';

/// Soft-tinted status label (confirmed / cancelled / open / full / pending…).
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  static Color colorFor(BuildContext context, String status) {
    final scheme = Theme.of(context).colorScheme;
    return switch (status) {
      'confirmed' || 'open' || 'approved' => const Color(0xFF1B873F),
      'cancelled' || 'rejected' => scheme.error,
      'completed' => scheme.primary,
      'full' => const Color(0xFFB26A00),
      _ => scheme.outline, // pending & friends
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = color ?? colorFor(context, label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: c, fontWeight: FontWeight.w800, letterSpacing: 0.4),
      ),
    );
  }
}
