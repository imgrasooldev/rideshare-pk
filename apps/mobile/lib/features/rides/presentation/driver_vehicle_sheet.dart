import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models/ride.dart';
import '../data/rides_repository.dart';

/// Fetches ride detail and shows who's driving + the vehicle, with a call
/// button (the driver's number is only returned once your booking is confirmed).
Future<void> showDriverSheet(BuildContext context, String rideId) async {
  final repo = context.read<RidesRepository>();
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => FutureBuilder<Ride>(
      future: repo.getById(rideId),
      builder: (ctx, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
              height: 180, child: Center(child: CircularProgressIndicator()));
        }
        if (!snap.hasData) {
          return const SizedBox(
              height: 160, child: Center(child: Text('Could not load driver details')));
        }
        return _DriverVehicle(ride: snap.data!);
      },
    ),
  );
}

class _DriverVehicle extends StatelessWidget {
  const _DriverVehicle({required this.ride});
  final Ride ride;

  Future<void> _call(BuildContext context) async {
    final phone = ride.driverPhone;
    if (phone == null) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await launchUrl(uri) && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Call $phone')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (ride.driverName?.trim().isNotEmpty ?? false) ? ride.driverName!.trim() : 'Driver';
    final hasVehicle = (ride.vehicleLabel.isNotEmpty) || (ride.vehiclePlate?.isNotEmpty ?? false);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                child: Text(name[0].toUpperCase(),
                    style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    if (ride.driverRatingCount > 0)
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFE19700)),
                          const SizedBox(width: 3),
                          Text(
                              '${ride.driverRatingAvg.toStringAsFixed(1)} (${ride.driverRatingCount})',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.outline)),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasVehicle)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.directions_car_filled_rounded,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ride.vehicleLabel.isNotEmpty ? ride.vehicleLabel : 'Vehicle',
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        if (ride.vehiclePlate?.isNotEmpty ?? false)
                          Text(ride.vehiclePlate!.toUpperCase(),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: theme.colorScheme.outline, letterSpacing: 1)),
                      ],
                    ),
                  ),
                  if (ride.vehicleSeats != null)
                    Text('${ride.vehicleSeats} seats',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
            ),
          const SizedBox(height: 14),
          if (ride.driverPhone != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _call(context),
                icon: const Icon(Icons.call_rounded, size: 18),
                label: const Text('Call driver'),
              ),
            )
          else
            Text('The driver\'s number becomes available once your booking is confirmed.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}
