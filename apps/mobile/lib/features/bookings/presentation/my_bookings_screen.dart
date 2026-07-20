import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/route_points.dart';
import '../../../core/widgets/status_pill.dart';
import '../bloc/my_bookings_bloc.dart';
import '../data/models/booking.dart';

class MyBookingsScreen extends StatelessWidget {
  const MyBookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyBookingsBloc, MyBookingsState>(
      builder: (context, state) => switch (state) {
        MyBookingsLoading() => const Center(child: CircularProgressIndicator()),
        MyBookingsError(:final message) => EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load bookings',
            message: message,
            isError: true,
            action: TextButton(
              onPressed: () => context.read<MyBookingsBloc>().add(const MyBookingsRequested()),
              child: const Text('Retry'),
            ),
          ),
        MyBookingsLoaded(:final bookings) when bookings.isEmpty => const EmptyState(
            icon: Icons.confirmation_number_outlined,
            title: 'No bookings yet',
            message: 'Find a ride on the Search tab — your seats will show up here.',
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: RoutePoints(
                      origin: booking.originLabel ?? '—',
                      destination: booking.destLabel ?? '—',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                StatusPill(booking.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              [
                if (booking.departAt != null)
                  DateFormat('EEE, d MMM • h:mm a').format(booking.departAt!),
                '${booking.seats} seat${booking.seats > 1 ? 's' : ''}',
                if (booking.pricePerSeat != null) 'Rs ${booking.pricePerSeat! * booking.seats}',
              ].join('  ·  '),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            if (booking.isActive) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
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
