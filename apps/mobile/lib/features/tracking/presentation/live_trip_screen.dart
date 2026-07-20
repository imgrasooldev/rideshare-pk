import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/widgets/status_pill.dart';
import '../../rides/data/models/ride.dart';
import '../bloc/driver_trip_cubit.dart';
import '../bloc/rating_cubit.dart';
import '../bloc/watch_trip_cubit.dart';
import '../data/location_source.dart';
import '../data/models/trip.dart';
import '../data/tracking_repository.dart';

enum LiveTripMode { driver, viewer }

/// Entry point that scopes the right cubits to this screen's lifetime.
class LiveTripPage extends StatelessWidget {
  const LiveTripPage({super.key, required this.mode, required this.ride});

  final LiveTripMode mode;
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    final repo = context.read<TrackingRepository>();
    if (mode == LiveTripMode.driver) {
      return BlocProvider(
        create: (_) => DriverTripCubit(
          repo,
          gps: GpsLocationSource(),
          fallback: DemoRouteSource(
            fromLat: ride.originLat,
            fromLng: ride.originLng,
            toLat: ride.destLat,
            toLng: ride.destLng,
          ),
        )..start(ride.id),
        child: _DriverView(ride: ride),
      );
    }
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => WatchTripCubit(repo)..watch(ride.id)),
        BlocProvider(create: (_) => RatingCubit(repo)),
      ],
      child: _ViewerView(ride: ride),
    );
  }
}

class _DriverView extends StatelessWidget {
  const _DriverView({required this.ride});
  final Ride ride;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DriverTripCubit, DriverTripState>(
      builder: (context, state) {
        final (label, live) = switch (state) {
          DriverTripStarting() => ('starting', false),
          DriverTripLive(:final demoMode) => (demoMode ? 'live · demo route' : 'live', true),
          DriverTripEnded() => ('ended', false),
          DriverTripError(:final message) => (message, false),
          _ => ('…', false),
        };
        final point = state is DriverTripLive ? state.lastSent : null;
        final shareToken = state is DriverTripLive ? state.trip.shareToken : null;

        return _TripScaffold(
          title: 'Live trip',
          ride: ride,
          point: point,
          statusLabel: label,
          isLive: live,
          actions: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: shareToken != null
                    ? () => copyShareLink(context, shareToken)
                    : null,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share link'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    state is DriverTripLive ? () => context.read<DriverTripCubit>().end() : null,
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('End trip'),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ViewerView extends StatefulWidget {
  const _ViewerView({required this.ride});
  final Ride ride;

  @override
  State<_ViewerView> createState() => _ViewerViewState();
}

class _ViewerViewState extends State<_ViewerView> {
  bool _ratingShown = false;

  Future<void> _showRatingDialog() async {
    if (_ratingShown) return;
    _ratingShown = true;
    final cubit = context.read<RatingCubit>();
    var stars = 5;
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Rate your driver'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setDialogState(() => stars = i),
                  icon: Icon(
                    i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 30,
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Skip')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit')),
          ],
        ),
      ),
    );
    if (submitted == true) {
      await cubit.rate(
          rideId: widget.ride.id, toUserId: widget.ride.driverId, stars: stars);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Thanks for the feedback!')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WatchTripCubit, WatchTripState>(
      listener: (context, state) {
        if (state is WatchEnded) _showRatingDialog();
      },
      builder: (context, state) {
        final theme = Theme.of(context);
        final (label, live) = switch (state) {
          WatchConnecting() => ('connecting', false),
          WatchLive(:final location) => (location == null ? 'waiting for driver' : 'live', true),
          WatchEnded() => ('ended', false),
          WatchError(:final message) => (message, false),
        };
        final point = state is WatchLive ? state.location : null;
        final shareToken = state is WatchLive ? state.shareToken : null;

        return _TripScaffold(
          title: 'Tracking ride',
          ride: widget.ride,
          point: point,
          statusLabel: label,
          isLive: live,
          actions: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    shareToken != null ? () => copyShareLink(context, shareToken) : null,
                icon: const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share link'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                  foregroundColor: theme.colorScheme.onError,
                ),
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('SOS logged with your live position'),
                    backgroundColor: theme.colorScheme.error,
                  ));
                  await context.read<TrackingRepository>().sos(
                        rideId: widget.ride.id,
                        lat: point?.lat,
                        lng: point?.lng,
                      );
                },
                icon: const Icon(Icons.sos_rounded, size: 18),
                label: const Text('SOS'),
              ),
            ),
          ],
          footer: state is WatchEnded
              ? TextButton(onPressed: _showRatingDialog, child: const Text('Rate this ride'))
              : null,
        );
      },
    );
  }
}

Future<void> copyShareLink(BuildContext context, String token) async {
  final url = context.read<TrackingRepository>().shareUrl(token);
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Live trip link copied — share it with family')),
    );
  }
}

class _TripScaffold extends StatefulWidget {
  const _TripScaffold({
    required this.title,
    required this.ride,
    required this.point,
    required this.statusLabel,
    required this.isLive,
    required this.actions,
    this.footer,
  });

  final String title;
  final Ride ride;
  final LivePoint? point;
  final String statusLabel;
  final bool isLive;
  final List<Widget> actions;
  final Widget? footer;

  @override
  State<_TripScaffold> createState() => _TripScaffoldState();
}

class _TripScaffoldState extends State<_TripScaffold> {
  final _mapController = MapController();

  @override
  void didUpdateWidget(_TripScaffold old) {
    super.didUpdateWidget(old);
    final p = widget.point;
    if (p != null && p != old.point) {
      _mapController.move(LatLng(p.lat, p.lng), _mapController.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ride = widget.ride;
    final center = widget.point != null
        ? LatLng(widget.point!.lat, widget.point!.lng)
        : LatLng(ride.originLat, ride.originLng);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: center, initialZoom: 13),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'pk.rideshare.rideshare_mobile',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(ride.originLat, ride.originLng),
                      child: Icon(Icons.trip_origin, color: theme.colorScheme.primary, size: 20),
                    ),
                    Marker(
                      point: LatLng(ride.destLat, ride.destLng),
                      child: Icon(Icons.location_on, color: theme.colorScheme.error, size: 26),
                    ),
                    if (widget.point != null)
                      Marker(
                        point: center,
                        width: 42,
                        height: 42,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.primary,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black38)],
                          ),
                          child:
                              const Icon(Icons.directions_car, color: Colors.white, size: 20),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('${ride.originLabel} → ${ride.destLabel}',
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                      ),
                      StatusPill(widget.statusLabel,
                          color: widget.isLive ? const Color(0xFF1B873F) : null),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(children: widget.actions),
                  if (widget.footer != null) widget.footer!,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
