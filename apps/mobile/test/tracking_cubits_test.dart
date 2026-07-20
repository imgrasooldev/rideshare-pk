import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare_mobile/features/tracking/bloc/driver_trip_cubit.dart';
import 'package:rideshare_mobile/features/tracking/bloc/watch_trip_cubit.dart';
import 'package:rideshare_mobile/features/tracking/data/location_source.dart';
import 'package:rideshare_mobile/features/tracking/data/models/trip.dart';
import 'package:rideshare_mobile/features/tracking/data/tracking_repository.dart';

class FakeTrackingRepository implements TrackingRepository {
  final pings = <({String rideId, double lat, double lng})>[];
  final events = StreamController<TrackingEvent>.broadcast();
  bool ended = false;

  static const trip =
      Trip(id: 't1', rideId: 'r1', liveStatus: 'live', shareToken: 'tok-123');

  @override
  Future<Trip> startTrip(String rideId) async => trip;

  @override
  Future<Trip> endTrip(String rideId) async {
    ended = true;
    return const Trip(id: 't1', rideId: 'r1', liveStatus: 'ended', shareToken: 'tok-123');
  }

  @override
  Future<bool> pingLocation(String rideId, double lat, double lng) async {
    pings.add((rideId: rideId, lat: lat, lng: lng));
    return true;
  }

  @override
  Future<({LivePoint? location, Trip? trip})> currentLocation(String rideId) async =>
      (location: null, trip: trip);

  @override
  Stream<TrackingEvent> watch(String rideId) => events.stream;

  @override
  String shareUrl(String shareToken) => 'https://x/shared/$shareToken';

  @override
  Future<void> rate({required String rideId, required String toUserId, required int stars, String? comment}) async {}

  @override
  Future<void> sos({String? rideId, double? lat, double? lng}) async {}
}

class NullGps implements LocationSource {
  @override
  Future<({double lat, double lng})?> next() async => null; // GPS unavailable
}

void main() {
  group('DriverTripCubit', () {
    test('starts trip, pings via GPS fallback demo route, ends', () async {
      final repo = FakeTrackingRepository();
      final cubit = DriverTripCubit(
        repo,
        gps: NullGps(),
        fallback: DemoRouteSource(
            fromLat: 31.51, fromLng: 74.34, toLat: 31.46, toLng: 74.41, steps: 10),
        pingInterval: const Duration(days: 1), // ticks driven manually
      );

      await cubit.start('r1');
      final live = cubit.state;
      expect(live, isA<DriverTripLive>());
      expect((live as DriverTripLive).trip.shareToken, 'tok-123');
      // First tick ran inside start(): fallback engaged, demo mode flagged.
      expect(repo.pings, hasLength(1));
      expect(live.demoMode, isTrue);
      expect(repo.pings.first.lat, closeTo(31.51, 1e-9));

      await cubit.tick();
      expect(repo.pings, hasLength(2));
      // Demo route moves toward the destination.
      expect(repo.pings[1].lat, lessThan(repo.pings[0].lat));

      await cubit.end();
      expect(repo.ended, isTrue);
      expect(cubit.state, isA<DriverTripEnded>());
      await cubit.close();
    });
  });

  group('WatchTripCubit', () {
    test('seeds snapshot, mirrors locations, transitions to ended', () async {
      final repo = FakeTrackingRepository();
      final cubit = WatchTripCubit(repo);

      await cubit.watch('r1');
      expect(cubit.state, isA<WatchLive>());
      expect((cubit.state as WatchLive).shareToken, 'tok-123');

      repo.events.add(TrackingLocation(
          LivePoint(lat: 31.5, lng: 74.35, at: DateTime.now())));
      await Future<void>.delayed(Duration.zero);
      expect((cubit.state as WatchLive).location?.lat, 31.5);

      repo.events.add(const TrackingEnded());
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isA<WatchEnded>());
      await cubit.close();
    });
  });
}
