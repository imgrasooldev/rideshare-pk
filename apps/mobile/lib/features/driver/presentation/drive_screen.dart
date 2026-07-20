import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../bloc/my_rides_cubit.dart';
import 'post_ride_screen.dart';

class DriveScreen extends StatelessWidget {
  const DriveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<MyRidesCubit, MyRidesState>(
        builder: (context, state) => switch (state) {
          MyRidesLoading() => const Center(child: CircularProgressIndicator()),
          MyRidesError(:final message) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(message),
                  TextButton(
                    onPressed: () => context.read<MyRidesCubit>().load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          MyRidesLoaded(:final rides) when rides.isEmpty => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No rides posted yet.\nShare your commute — post your first ride.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          MyRidesLoaded(:final rides) => RefreshIndicator(
              onRefresh: () => context.read<MyRidesCubit>().load(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: rides.length,
                itemBuilder: (context, i) {
                  final ride = rides[i];
                  final theme = Theme.of(context);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      title: Text('${ride.originLabel} → ${ride.destLabel}'),
                      subtitle: Text(
                        '${DateFormat('EEE, d MMM • h:mm a').format(ride.departAt)}\n'
                        '${ride.seatsAvailable}/${ride.seatsTotal} seats left · Rs ${ride.pricePerSeat}/seat',
                      ),
                      isThreeLine: true,
                      trailing: Chip(
                        label: Text(ride.status),
                        backgroundColor: switch (ride.status) {
                          'open' => Colors.green.shade100,
                          'full' => theme.colorScheme.tertiaryContainer,
                          _ => theme.colorScheme.surfaceContainerHighest,
                        },
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
