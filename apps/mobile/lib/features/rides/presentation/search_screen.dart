import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

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
              RideSearchInitial() => const _Hint('Pick your route and search for shared rides.'),
              RideSearchLoading() =>
                const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
              RideSearchError(:final message) => _Hint(message, isError: true),
              RideSearchLoaded(:final rides) when rides.isEmpty =>
                const _Hint('No rides on this route yet. Try another day or a wider corridor.'),
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
    final time = DateFormat('h:mm a').format(ride.departAt);
    final bookingState = context.watch<BookingActionCubit>().state;
    final inFlight = bookingState is BookingInFlight && bookingState.rideId == ride.id;

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
                  child: Text('${ride.originLabel} → ${ride.destLabel}',
                      style: theme.textTheme.titleMedium),
                ),
                if (ride.ladiesOnly)
                  const Tooltip(
                    message: 'Ladies only',
                    child: Icon(Icons.female, color: Colors.pink),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text(time),
                const SizedBox(width: 16),
                Icon(Icons.event_seat, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 4),
                Text('${ride.seatsAvailable} of ${ride.seatsTotal} seats'),
                const Spacer(),
                Text('Rs ${ride.pricePerSeat}',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(color: theme.colorScheme.primary)),
                Text('/seat', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
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

class _Hint extends StatelessWidget {
  const _Hint(this.text, {this.isError = false});
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: isError ? theme.colorScheme.error : theme.colorScheme.outline,
        ),
      ),
    );
  }
}
