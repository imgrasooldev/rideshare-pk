import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import 'models/trip.dart';

class TrackingRepository {
  TrackingRepository(this._api, this._storage);

  final ApiClient _api;
  final TokenStorage _storage;

  Future<Trip> startTrip(String rideId) async =>
      Trip.fromJson(await _api.post('/trips/$rideId/start'));

  Future<Trip> endTrip(String rideId) async =>
      Trip.fromJson(await _api.post('/trips/$rideId/end'));

  Future<bool> pingLocation(String rideId, double lat, double lng) async {
    final res = await _api.post('/trips/$rideId/location', body: {'lat': lat, 'lng': lng});
    return res['accepted'] as bool? ?? false;
  }

  Future<({Trip? trip, LivePoint? location})> currentLocation(String rideId) async {
    final res = await _api.get('/trips/$rideId/location');
    return (
      trip: res['trip'] != null ? Trip.fromJson(res['trip'] as Map<String, dynamic>) : null,
      location: res['location'] != null
          ? LivePoint.fromJson(res['location'] as Map<String, dynamic>)
          : null,
    );
  }

  String shareUrl(String shareToken) =>
      '${AppConfig.apiBaseUrl}${AppConfig.apiPrefix}/trips/shared/$shareToken';

  Future<void> rate({
    required String rideId,
    required String toUserId,
    required int stars,
    String? comment,
  }) async {
    await _api.post('/ratings', body: {
      'rideId': rideId,
      'toUserId': toUserId,
      'stars': stars,
      'comment': ?comment,
    });
  }

  Future<void> sos({String? rideId, double? lat, double? lng}) async {
    await _api.post('/safety/sos', body: {
      'rideId': ?rideId,
      'lat': ?lat,
      'lng': ?lng,
    });
  }

  /// Live WS subscription. Cancelling the subscription closes the socket.
  Stream<TrackingEvent> watch(String rideId) {
    final controller = StreamController<TrackingEvent>();
    sio.Socket? socket;

    controller.onListen = () async {
      final token = await _storage.accessToken;
      socket = sio.io(
        '${AppConfig.apiBaseUrl}/trips',
        sio.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token, 'rideId': rideId})
            .build(),
      );
      socket!
        ..on('location', (data) {
          if (data is Map) {
            controller.add(TrackingLocation(LivePoint.fromJson(Map<String, dynamic>.from(data))));
          }
        })
        ..on('ended', (_) => controller.add(const TrackingEnded()))
        ..on('error', (data) {
          final message = data is Map ? (data['message']?.toString() ?? 'error') : 'error';
          controller.add(TrackingError(message));
        })
        ..onConnectError((_) => controller.add(const TrackingError('Connection failed')));
    };
    controller.onCancel = () {
      socket?.dispose();
    };
    return controller.stream;
  }
}
