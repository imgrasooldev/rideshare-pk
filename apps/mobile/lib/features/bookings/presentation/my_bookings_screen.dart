import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/route_points.dart';
import '../../../core/widgets/status_pill.dart';
import '../../rides/data/rides_repository.dart';
import '../../rides/presentation/driver_vehicle_sheet.dart';
import '../../tracking/presentation/live_trip_screen.dart';
import '../../disputes/presentation/report_sheet.dart';
import '../bloc/my_bookings_bloc.dart';
import '../data/models/booking.dart';
import 'receipt_screen.dart';

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
            if (booking.status == 'countered') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF3D9A6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Driver counter-offered Rs ${booking.offeredPrice}/seat',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, color: Color(0xFF8A5A00))),
                    if (booking.pricePerSeat != null)
                      Text('Original: Rs ${booking.pricePerSeat}/seat',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFA9803A))),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: cancelling
                                ? null
                                : () => context
                                    .read<MyBookingsBloc>()
                                    .add(BookingCounterResponded(booking.id, false)),
                            child: const Text('Decline'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: cancelling
                                ? null
                                : () => context
                                    .read<MyBookingsBloc>()
                                    .add(BookingCounterResponded(booking.id, true)),
                            child: Text(cancelling ? '…' : 'Accept Rs ${booking.offeredPrice}'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (booking.status == 'requested') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Waiting for the driver to accept',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    onPressed: cancelling
                        ? null
                        : () => _cancelWithReason(context, booking.id),
                    child: Text(cancelling ? 'Cancelling…' : 'Cancel'),
                  ),
                ],
              ),
            ] else if (booking.status == 'confirmed') ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () async {
                        final ride = await context
                            .read<RidesRepository>()
                            .getById(booking.rideId);
                        if (context.mounted) {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  LiveTripPage(mode: LiveTripMode.viewer, ride: ride),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: const Text('Track ride'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Driver & vehicle',
                    onPressed: () => showDriverSheet(context, booking.rideId),
                    icon: const Icon(Icons.person_pin_circle_outlined),
                  ),
                  IconButton(
                    tooltip: 'Receipt',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => ReceiptScreen(booking: booking)),
                    ),
                    icon: const Icon(Icons.receipt_long_outlined),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                    onPressed: cancelling
                        ? null
                        : () => _cancelWithReason(context, booking.id),
                    child: Text(cancelling ? 'Cancelling…' : 'Cancel'),
                  ),
                ],
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showReportSheet(context, bookingId: booking.id),
                icon: Icon(Icons.flag_outlined, size: 16, color: theme.colorScheme.outline),
                label: Text('Report a problem',
                    style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.outline)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _cancelReasons = [
  'Changed my plans',
  'Found another ride',
  'Departure time changed',
  'Driver too far',
  'Price too high',
  'Other',
];

/// Asks a quick reason, then dispatches the cancel. Free to cancel — the
/// reason just helps improve the marketplace.
Future<void> _cancelWithReason(BuildContext context, String bookingId) async {
  final bloc = context.read<MyBookingsBloc>();
  final reason = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text('Why are you cancelling?',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Free to cancel. Frequent last-minute cancellations may limit your account.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          for (final r in _cancelReasons)
            ListTile(title: Text(r), onTap: () => Navigator.pop(ctx, r)),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (reason == null) return; // dismissed — don't cancel
  bloc.add(BookingCancelPressed(bookingId, reason: reason));
}
