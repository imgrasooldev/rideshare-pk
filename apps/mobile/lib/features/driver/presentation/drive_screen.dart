import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/route_points.dart';
import '../../../core/widgets/status_pill.dart';
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
          MyRidesLoaded(:final rides) when rides.isEmpty => const EmptyState(
              icon: Icons.add_road_rounded,
              title: 'No rides posted yet',
              message: 'Share your commute — post your first ride and fill your empty seats.',
            ),
          MyRidesLoaded(:final rides) => RefreshIndicator(
              onRefresh: () => context.read<MyRidesCubit>().load(),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: rides.length,
                itemBuilder: (context, i) {
                  final ride = rides[i];
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
                                    origin: ride.originLabel,
                                    destination: ride.destLabel,
                                  ),
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
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Post ride'),
      ),
    );
  }
}
