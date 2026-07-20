import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/route_points.dart';
import '../../../core/widgets/status_pill.dart';
import '../../bookings/bloc/booking_action_cubit.dart';
import '../bloc/ride_search_bloc.dart';
import '../data/models/ride.dart';
import '../data/rides_repository.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Hub _pickup = lahoreHubs[1]; // DHA Phase 5
  Hub _drop = lahoreHubs[0]; // Gulberg
  DateTime _day = DateTime.now().add(const Duration(days: 1));
  bool _ladiesOnly = false;

  void _search() {
    context.read<RideSearchBloc>().add(RideSearchSubmitted(
          pickup: _pickup,
          drop: _drop,
          day: _day,
          ladiesOnly: _ladiesOnly,
        ));
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) setState(() => _day = picked);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<BookingActionCubit, BookingActionState>(
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state is BookingSuccess) {
          messenger.showSnackBar(SnackBar(
            content: Text('Seat booked! ${state.booking.originLabel ?? ''} ride confirmed.'),
            backgroundColor: Colors.green.shade700,
          ));
          context.read<BookingActionCubit>().reset();
          _search(); // refresh seat counts
        } else if (state is BookingFailure) {
          messenger.showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ));
          context.read<BookingActionCubit>().reset();
        }
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SearchForm(
            pickup: _pickup,
            drop: _drop,
            day: _day,
            ladiesOnly: _ladiesOnly,
            onPickup: (h) => setState(() => _pickup = h),
            onDrop: (h) => setState(() => _drop = h),
            onPickDay: _pickDay,
            onLadiesOnly: (v) => setState(() => _ladiesOnly = v),
            onSwap: () => setState(() {
              final t = _pickup;
              _pickup = _drop;
              _drop = t;
            }),
            onSearch: _search,
          ),
          const SizedBox(height: 16),
          BlocBuilder<RideSearchBloc, RideSearchState>(
            builder: (context, state) => switch (state) {
              RideSearchInitial() => const EmptyState(
                  icon: Icons.route_outlined,
                  title: 'Where are you headed?',
                  message: 'Pick your route and search for shared rides.',
                ),
              RideSearchLoading() =>
                const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
              RideSearchError(:final message) => EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Something went wrong',
                  message: message,
                  isError: true,
                ),
              RideSearchLoaded(:final rides) when rides.isEmpty => const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No rides on this route yet',
                  message: 'Try another day or a wider corridor — new rides are posted daily.',
                ),
              RideSearchLoaded(:final rides, :final hasMore, :final loadingMore) => Column(
                  children: [
                    for (final ride in rides) _RideCard(ride: ride),
                    if (hasMore)
                      TextButton(
                        onPressed: loadingMore
                            ? null
                            : () => context
                                .read<RideSearchBloc>()
                                .add(const RideSearchNextPageRequested()),
                        child: Text(loadingMore ? 'Loading…' : 'Load more'),
                      ),
                  ],
                ),
            },
          ),
        ],
      ),
    );
  }
}

class _SearchForm extends StatelessWidget {
  const _SearchForm({
    required this.pickup,
    required this.drop,
    required this.day,
    required this.ladiesOnly,
    required this.onPickup,
    required this.onDrop,
    required this.onPickDay,
    required this.onLadiesOnly,
    required this.onSwap,
    required this.onSearch,
  });

  final Hub pickup;
  final Hub drop;
  final DateTime day;
  final bool ladiesOnly;
  final ValueChanged<Hub> onPickup;
  final ValueChanged<Hub> onDrop;
  final VoidCallback onPickDay;
  final ValueChanged<bool> onLadiesOnly;
  final VoidCallback onSwap;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.near_me_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text('Where to?',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _HubDropdown(label: 'Pickup', value: pickup, onChanged: onPickup),
                      const SizedBox(height: 12),
                      _HubDropdown(label: 'Drop-off', value: drop, onChanged: onDrop),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Swap',
                  onPressed: onSwap,
                  icon: const Icon(Icons.swap_vert),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPickDay,
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat('EEE, d MMM').format(day)),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    const Text('Ladies only'),
                    Switch(value: ladiesOnly, onChanged: onLadiesOnly),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: onSearch,
              icon: const Icon(Icons.search),
              label: const Text('Find rides'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubDropdown extends StatelessWidget {
  const _HubDropdown({required this.label, required this.value, required this.onChanged});

  final String label;
  final Hub value;
  final ValueChanged<Hub> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<Hub>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        for (final hub in lahoreHubs)
          DropdownMenuItem(value: hub, child: Text(hub.label, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: (h) {
        if (h != null) onChanged(h);
      },
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bookingState = context.watch<BookingActionCubit>().state;
    final inFlight = bookingState is BookingInFlight && bookingState.rideId == ride.id;
    final seatsLow = ride.seatsAvailable > 0 && ride.seatsAvailable <= 1;

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
                      origin: ride.originLabel,
                      destination: ride.destLabel,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Rs ${ride.pricePerSeat}',
                        style: theme.textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
                    Text('/seat',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text(DateFormat('h:mm a').format(ride.departAt),
                    style: theme.textTheme.labelLarge),
                const SizedBox(width: 14),
                Icon(Icons.airline_seat_recline_normal_rounded,
                    size: 16,
                    color: seatsLow ? const Color(0xFFB26A00) : theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text(
                  '${ride.seatsAvailable} of ${ride.seatsTotal} seats',
                  style: theme.textTheme.labelLarge?.copyWith(
                      color: seatsLow ? const Color(0xFFB26A00) : null,
                      fontWeight: seatsLow ? FontWeight.w700 : null),
                ),
                const Spacer(),
                if (ride.ladiesOnly) const StatusPill('Ladies only', color: Color(0xFFC2185B)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: ride.seatsAvailable > 0 && !inFlight
                    ? () => context.read<BookingActionCubit>().book(ride.id, 1)
                    : null,
                child: Text(inFlight
                    ? 'Booking…'
                    : ride.seatsAvailable > 0
                        ? 'Book a seat'
                        : 'Full'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
