import 'dart:math';

import '../../../core/network/api_client.dart';
import 'models/booking.dart';
import 'models/seat_request.dart';

class BookingsRepository {
  BookingsRepository(this._api);

  final ApiClient _api;
  final _rng = Random();

  /// Client-generated idempotency key: a retry of the same tap re-sends the
  /// same key, so the server returns the original booking instead of
  /// double-charging seats.
  String newIdempotencyKey() =>
      'bk-${DateTime.now().microsecondsSinceEpoch}-${_rng.nextInt(1 << 32)}';

  Future<Booking> book({
    required String rideId,
    required int seats,
    required String idempotencyKey,
  }) async {
    final res = await _api.post('/bookings', body: {
      'rideId': rideId,
      'seats': seats,
      'idempotencyKey': idempotencyKey,
    });
    return Booking.fromJson(res);
  }

  Future<Booking> cancel(String bookingId) async =>
      Booking.fromJson(await _api.post('/bookings/$bookingId/cancel'));

  /// Rider accepts/declines a driver's counter-offer.
  Future<Booking> respondToCounter(String bookingId, bool accept) async => Booking.fromJson(
      await _api.post('/bookings/$bookingId/respond', body: {'accept': accept}));

  // --- Driver dispatch inbox ---

  Future<List<SeatRequest>> requests() async {
    final res = await _api.getList('/bookings/requests');
    return res.cast<Map<String, dynamic>>().map(SeatRequest.fromJson).toList();
  }

  Future<void> accept(String bookingId) => _api.post('/bookings/$bookingId/accept');

  Future<void> reject(String bookingId) => _api.post('/bookings/$bookingId/reject');

  Future<void> counter(String bookingId, int offeredPrice) =>
      _api.post('/bookings/$bookingId/counter', body: {'offeredPrice': offeredPrice});

  Future<({List<Booking> items, String? nextCursor})> mine({String? cursor}) async {
    final res = await _api.get('/bookings/mine', query: {'cursor': ?cursor});
    return (
      items: (res['items'] as List<dynamic>)
          .map((e) => Booking.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: res['nextCursor'] as String?,
    );
  }
}
