import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/route_points.dart';
import '../../../core/widgets/seat_map.dart';
import '../../../core/widgets/status_pill.dart';
import '../../../core/network/api_exception.dart';
import '../../bookings/bloc/booking_action_cubit.dart';
import '../../categories/bloc/categories_cubit.dart';
import '../../messages/presentation/chat_screen.dart';
import '../../places/bloc/places_cubit.dart';
import '../../places/data/places_repository.dart';
import '../../places/presentation/place_picker.dart';
import '../../subscriptions/data/subscriptions_repository.dart';
import '../bloc/ride_search_bloc.dart';
import '../data/models/ride.dart';
import '../data/rides_repository.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialVertical, this.initialLadiesOnly = false});

  /// Pre-selected category (ride vertical) to filter by, e.g. 'office'.
  final String? initialVertical;

  /// Pre-selects the ladies-only filter (used by the Ladies category tile).
  final bool initialLadiesOnly;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  Hub? _pickup;
  Hub? _drop;
  DateTime _day = DateTime.now().add(const Duration(days: 1));
  late bool _ladiesOnly = widget.initialLadiesOnly;
  String? _vehicleType; // null = any
  late String? _vertical = widget.initialVertical;

  @override
  void initState() {
    super.initState();
    // If we arrived here from a category tile, run the filtered search once the
    // default hubs are in place (after the first frame).
    if (_vertical != null || _ladiesOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void didUpdateWidget(SearchScreen old) {
    super.didUpdateWidget(old);
    // A new category was tapped on the dashboard while this tab already existed.
    if (widget.initialVertical != old.initialVertical ||
        widget.initialLadiesOnly != old.initialLadiesOnly) {
      setState(() {
        _vertical = widget.initialVertical;
        _ladiesOnly = widget.initialLadiesOnly;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  String _verticalLabel(String key) {
    final state = context.read<CategoriesCubit>().state;
    if (state is CategoriesLoaded) {
      for (final c in state.items) {
        if (c.key == key) return c.label;
      }
    }
    return key.isEmpty ? key : key[0].toUpperCase() + key.substring(1);
  }

  void _search() {
    final pickup = _pickup;
    final drop = _drop;
    if (pickup == null || drop == null) return;
    context.read<RideSearchBloc>().add(RideSearchSubmitted(
          pickup: pickup,
          drop: drop,
          day: _day,
          ladiesOnly: _ladiesOnly,
          vehicleType: _vehicleType,
          vertical: _vertical,
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
    final hubs = context.watch<PlacesCubit>().state.hubs;
    if (hubs.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator()),
      );
    }
    // Seed sensible defaults from the curated hubs; a custom searched address
    // (not in the hub list) is preserved instead of being reset.
    _pickup ??= hubs.length > 1 ? hubs[1] : hubs.first;
    _drop ??= hubs.first;
    return BlocListener<BookingActionCubit, BookingActionState>(
      listener: (context, state) {
        final messenger = ScaffoldMessenger.of(context);
        if (state is BookingSuccess) {
          messenger.showSnackBar(SnackBar(
            content: const Text('Request sent — the driver will accept or counter-offer.'),
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
            hubs: hubs,
            pickup: _pickup!,
            drop: _drop!,
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
          if (_vertical != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Chip(
                  avatar: Icon(Icons.category_rounded,
                      size: 16, color: Theme.of(context).colorScheme.primary),
                  label: Text(_verticalLabel(_vertical!)),
                  backgroundColor:
                      Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                  side: BorderSide(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                  onDeleted: () {
                    setState(() => _vertical = null);
                    _search();
                  },
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _vehicleType == null,
                  onSelected: (_) => setState(() => _vehicleType = null),
                ),
                for (final type in vehicleTypes) ...[
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: Icon(vehicleTypeIcon(type), size: 16),
                    label: Text(vehicleTypeLabel(type)),
                    selected: _vehicleType == type,
                    onSelected: (_) => setState(() => _vehicleType = type),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
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
    required this.hubs,
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

  final List<Hub> hubs;
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
                      _PlaceField(
                          label: 'Pickup', value: pickup, hubs: hubs, onChanged: onPickup),
                      const SizedBox(height: 12),
                      _PlaceField(
                          label: 'Drop-off', value: drop, hubs: hubs, onChanged: onDrop),
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
            _EtaEstimate(pickup: pickup, drop: drop),
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

/// Shows the driving distance + ETA for the chosen pickup/drop (via OSRM,
/// with a straight-line fallback). Re-fetches when either point changes.
class _EtaEstimate extends StatelessWidget {
  const _EtaEstimate({required this.pickup, required this.drop});
  final Hub pickup;
  final Hub drop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final key = '${pickup.lat},${pickup.lng}-${drop.lat},${drop.lng}';
    return FutureBuilder(
      key: ValueKey(key),
      future: context.read<PlacesRepository>().route(pickup, drop),
      builder: (context, snap) {
        if (!snap.hasData) return const SizedBox(height: 8);
        final r = snap.data!;
        if (r.distanceKm <= 0) return const SizedBox(height: 8);
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(Icons.route_rounded, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text('${r.distanceKm} km  ·  ~${r.durationMin} min drive',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }
}

/// A tappable pickup/drop field that opens the address search (any address),
/// with the curated hubs offered as quick suggestions.
class _PlaceField extends StatelessWidget {
  const _PlaceField({
    required this.label,
    required this.value,
    required this.hubs,
    required this.onChanged,
  });

  final String label;
  final Hub value;
  final List<Hub> hubs;
  final ValueChanged<Hub> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPickup = label == 'Pickup';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final city = context.read<PlacesCubit>().state.city;
        final picked =
            await showPlacePicker(context, title: label, hubs: hubs, city: city);
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          prefixIcon: Icon(
            isPickup ? Icons.trip_origin_rounded : Icons.place_rounded,
            size: 18,
            color: isPickup ? const Color(0xFF12A46B) : theme.colorScheme.primary,
          ),
        ),
        child: Text(value.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? theme.colorScheme.outline),
        const SizedBox(width: 4),
        Text(
          text,
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: color != null ? FontWeight.w700 : null,
          ),
        ),
      ],
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
            Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Meta(
                    icon: vehicleTypeIcon(ride.vehicleType),
                    text: vehicleTypeLabel(ride.vehicleType)),
                if (ride.driverRatingCount > 0)
                  _Meta(
                      icon: Icons.star_rounded,
                      text:
                          '${ride.driverRatingAvg.toStringAsFixed(1)} (${ride.driverRatingCount})',
                      color: const Color(0xFFE19700)),
                _Meta(
                    icon: Icons.schedule_rounded,
                    text: DateFormat('h:mm a').format(ride.departAt)),
                _Meta(
                  icon: Icons.airline_seat_recline_normal_rounded,
                  text: '${ride.seatsAvailable} of ${ride.seatsTotal} seats',
                  color: seatsLow ? const Color(0xFFB26A00) : null,
                ),
                if (ride.ladiesOnly) const StatusPill('Ladies only', color: Color(0xFFC2185B)),
                const StatusPill('Cash', color: Color(0xFF00695C)),
              ],
            ),
            // Van/Hiace: show the seat chart so riders see what's already booked.
            if (ride.vehicleType == 'minivan' || ride.vehicleType == 'hiace') ...[
              const SizedBox(height: 14),
              SeatMap(
                seatsTotal: ride.seatsTotal,
                seatsAvailable: ride.seatsAvailable,
                perRow: ride.vehicleType == 'hiace' ? 4 : 3,
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: ride.seatsAvailable > 0 && !inFlight
                    ? () => context.read<BookingActionCubit>().book(ride.id, 1)
                    : null,
                child: Text(inFlight
                    ? 'Requesting…'
                    : ride.seatsAvailable > 0
                        ? 'Request seat'
                        : 'Full'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _subscribeMonthly(context, ride),
                    icon: const Icon(Icons.event_repeat_rounded, size: 18),
                    label: const Text('Subscribe'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ChatScreen(
                        rideId: ride.id,
                        otherId: ride.driverId,
                        title: 'Driver',
                        subtitle: '${ride.originLabel} → ${ride.destLabel}',
                      ),
                    )),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: const Text('Message'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Turn a daily route into a monthly subscription — no more booking each morning.
Future<void> _subscribeMonthly(BuildContext context, Ride ride) async {
  final messenger = ScaffoldMessenger.of(context);
  final repo = context.read<SubscriptionsRepository>();
  try {
    final sub = await repo.subscribe(ride.id);
    messenger.showSnackBar(SnackBar(
      content: Text('Subscribed — Rs ${sub.pricePerMonth}/month'),
      backgroundColor: Colors.green.shade700,
    ));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text('Could not subscribe')));
  }
}
