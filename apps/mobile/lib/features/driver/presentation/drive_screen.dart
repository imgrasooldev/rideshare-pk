import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/route_points.dart';
import '../../../core/widgets/seat_map.dart';
import '../../../core/widgets/status_pill.dart';
import '../../rides/data/rides_repository.dart';
import '../../earnings/bloc/earnings_cubit.dart';
import '../../earnings/data/earnings_repository.dart';
import '../../tracking/presentation/live_trip_screen.dart';
import '../bloc/my_rides_cubit.dart';
import 'post_ride_screen.dart';

class DriveScreen extends StatelessWidget {
  const DriveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: BlocBuilder<MyRidesCubit, MyRidesState>(
        builder: (context, state) => switch (state) {
          MyRidesLoading() => const Center(child: CircularProgressIndicator()),
          MyRidesError(:final message) => EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load your rides',
              message: message,
              isError: true,
              action: TextButton(
                onPressed: () => context.read<MyRidesCubit>().load(),
                child: const Text('Retry'),
              ),
            ),
          MyRidesLoaded(:final rides) => RefreshIndicator(
              onRefresh: () {
                final rides = context.read<MyRidesCubit>().load();
                final earnings = context.read<EarningsCubit>().load();
                return Future.wait([rides, earnings]);
              },
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  const _EarningsCard(),
                  const SizedBox(height: 20),
                  if (rides.isEmpty)
                    const _EmptyRides()
                  else ...[
                    Text('Your rides',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    for (final ride in rides) _RideCard(ride: ride),
                  ],
                ],
              ),
            ),
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final posted = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const PostRideScreen()),
          );
          if (posted == true && context.mounted) {
            context.read<MyRidesCubit>().load();
            context.read<EarningsCubit>().load();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Post ride'),
      ),
    );
  }
}

class _EmptyRides extends StatelessWidget {
  const _EmptyRides();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.add_road_rounded, size: 40, color: theme.colorScheme.outline),
          const SizedBox(height: 10),
          Text('No rides posted yet',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Post your first ride and fill your empty seats.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EarningsCubit, EarningsState>(
      builder: (context, state) {
        final e = state is EarningsLoaded ? state.data : null;
        return Column(
          children: [
            _Hero(e: e),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Stat(label: 'Today', value: e == null ? '—' : 'Rs ${e.today}')),
                const SizedBox(width: 10),
                Expanded(child: _Stat(label: 'Trips (mo)', value: e == null ? '—' : '${e.tripsThisMonth}')),
                const SizedBox(width: 10),
                Expanded(
                    child: _Stat(
                        label: 'Subscribers',
                        value: e == null ? '—' : '${e.activeSubscribers}')),
                const SizedBox(width: 10),
                Expanded(
                    child: _Stat(
                        label: 'Rating',
                        value: e == null || e.ratingCount == 0
                            ? '—'
                            : e.ratingAvg.toStringAsFixed(1),
                        star: e != null && e.ratingCount > 0)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.e});
  final Earnings? e;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final e = this.e;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF5A47), Color(0xFFE81E2D)],
        ),
        boxShadow: [
          BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('Earnings this month',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(e == null ? 'Rs —' : 'Rs ${e.thisMonth}',
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              _pill('Net Rs ${e?.netThisMonth ?? '—'}'),
              const SizedBox(width: 8),
              _pill(
                  'Commission Rs ${e?.commissionThisMonth ?? '—'} · ${((e?.commissionRate ?? 0) * 100).round()}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
        child: Text(text,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.star = false});
  final String label;
  final String value;
  final bool star;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
              ),
              if (star) Icon(Icons.star_rounded, size: 13, color: theme.colorScheme.primary),
            ],
          ),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride});
  final dynamic ride;

  Future<void> _manageSeats(BuildContext context) async {
    final reserved = (ride.seatsTotal - ride.seatsAvailable) as int;
    final cap = ride.vehicleType == 'bike'
        ? 1
        : ride.vehicleType == 'hiace'
            ? 14
            : ride.vehicleType == 'minivan'
                ? 8
                : 6;
    final repo = context.read<RidesRepository>();
    final rides = context.read<MyRidesCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final total = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        int value = ride.seatsTotal as int;
        return StatefulBuilder(
          builder: (ctx, setState) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total seats',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('$reserved already booked — you can\'t go below that.',
                    style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.outlined(
                      onPressed: value > (reserved < 1 ? 1 : reserved)
                          ? () => setState(() => value--)
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 64,
                      child: Text('$value',
                          textAlign: TextAlign.center,
                          style: Theme.of(ctx)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ),
                    IconButton.outlined(
                      onPressed: value < cap ? () => setState(() => value++) : null,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, value),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (total == null || total == ride.seatsTotal) return;
    try {
      await repo.updateSeats(ride.id as String, total);
      await rides.load();
      messenger.showSnackBar(SnackBar(content: Text('Seats updated to $total')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not update seats')));
    }
  }

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
                    child: RoutePoints(origin: ride.originLabel, destination: ride.destLabel),
                  ),
                ),
                const SizedBox(width: 12),
                StatusPill(ride.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${DateFormat('EEE, d MMM • h:mm a').format(ride.departAt)}'
              '  ·  ${ride.seatsAvailable}/${ride.seatsTotal} seats left'
              '  ·  Rs ${ride.pricePerSeat}/seat',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
            if (ride.vehicleType == 'minivan' || ride.vehicleType == 'hiace') ...[
              const SizedBox(height: 14),
              SeatMap(
                seatsTotal: ride.seatsTotal,
                seatsAvailable: ride.seatsAvailable,
                perRow: ride.vehicleType == 'hiace' ? 4 : 3,
              ),
            ],
            if (ride.status == 'open' || ride.status == 'full') ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _manageSeats(context),
                      icon: const Icon(Icons.event_seat_rounded, size: 18),
                      label: const Text('Manage seats'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LiveTripPage(mode: LiveTripMode.driver, ride: ride),
                        ),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text('Start'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
