import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../data/models/booking.dart';

/// A simple, screenshot-friendly trip receipt built from the booking.
class ReceiptScreen extends StatelessWidget {
  const ReceiptScreen({super.key, required this.booking});
  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final perSeat = booking.effectivePrice ?? 0;
    final total = perSeat * booking.seats;
    final ref = booking.id.length > 8 ? booking.id.substring(0, 8).toUpperCase() : booking.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Rideshare PK',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Text('Trip receipt · #$ref',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _Row(label: 'Date',
                    value: booking.departAt != null
                        ? DateFormat('EEE, d MMM yyyy • h:mm a').format(booking.departAt!)
                        : DateFormat('EEE, d MMM yyyy').format(booking.createdAt)),
                const SizedBox(height: 10),
                _Row(label: 'From', value: booking.originLabel ?? '—'),
                const SizedBox(height: 10),
                _Row(label: 'To', value: booking.destLabel ?? '—'),
                const SizedBox(height: 10),
                _Row(label: 'Status', value: _pretty(booking.status)),
                const Divider(height: 28),
                _Row(label: '${booking.seats} seat${booking.seats > 1 ? 's' : ''} × Rs $perSeat',
                    value: 'Rs $total'),
                const SizedBox(height: 8),
                _Row(label: 'Payment', value: 'Cash'),
                const Divider(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('Rs $total',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                            color: theme.colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Cost-shared carpool fare, paid in cash to the driver. Keep this receipt for your records.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text('Screenshot to save or share',
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline)),
          ),
        ],
      ),
    );
  }

  static String _pretty(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(label,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
        ),
        Expanded(
          child: Text(value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
