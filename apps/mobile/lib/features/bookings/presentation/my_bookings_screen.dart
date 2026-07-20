import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../bloc/my_bookings_bloc.dart';
import '../data/models/booking.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyBookingsBloc, MyBookingsState>(
      builder: (context, state) => switch (state) {
        MyBookingsLoading() => const Center(child: CircularProgressIndicator()),
        MyBookingsError(:final message) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                TextButton(
                  onPressed: () =>
                      context.read<MyBookingsBloc>().add(const MyBookingsRequested()),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        MyBookingsLoaded(:final bookings) when bookings.isEmpty => const Center(
            child: Text('No bookings yet — find a ride on the Search tab.'),
          ),
        MyBookingsLoaded(:final bookings, :final cancelling) => RefreshIndicator(
            onRefresh: () async =>
                context.read<MyBookingsBloc>().add(const MyBookingsRequested()),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bookings.length,
              itemBuilder: (context, i) => _BookingCard(
                booking: bookings[i],
                cancelling: cancelling.contains(bookings[i].id),
              ),
            ),
          ),
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking, required this.cancelling});

  final Booking booking;
  final bool cancelling;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (booking.status) {
      'confirmed' => Colors.green.shade700,
      'cancelled' => theme.colorScheme.outline,
      'completed' => theme.colorScheme.primary,
      _ => theme.colorScheme.tertiary,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${booking.originLabel ?? '—'} → ${booking.destLabel ?? '—'}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(booking.status),
                  labelStyle: theme.textTheme.labelSmall?.copyWith(color: Colors.white),
                  backgroundColor: statusColor,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              [
                if (booking.departAt != null)
                  DateFormat('EEE, d MMM • h:mm a').format(booking.departAt!),
                '${booking.seats} seat${booking.seats > 1 ? 's' : ''}',
                if (booking.pricePerSeat != null) 'Rs ${booking.pricePerSeat! * booking.seats}',
              ].join('  ·  '),
              style: theme.textTheme.bodyMedium,
            ),
            if (booking.isActive) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: cancelling
                      ? null
                      : () => context
                          .read<MyBookingsBloc>()
                          .add(BookingCancelPressed(booking.id)),
                  child: Text(cancelling ? 'Cancelling…' : 'Cancel booking'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
