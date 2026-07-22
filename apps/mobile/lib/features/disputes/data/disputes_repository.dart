import '../../../core/network/api_client.dart';

class DisputesRepository {
  DisputesRepository(this._api);
  final ApiClient _api;

  Future<void> file({
    required String category,
    required String message,
    String? bookingId,
  }) =>
      _api.post('/disputes', body: {
        'category': category,
        'message': message,
        'bookingId': ?bookingId,
      });
}
