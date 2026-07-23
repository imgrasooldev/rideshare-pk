import '../../../core/network/api_client.dart';

class DisputesRepository {
  DisputesRepository(this._api);
  final ApiClient _api;

  /// [reportedUserId] names the PERSON being reported, so the admin queue can
  /// see who is complained about — not just that a trip went wrong.
  Future<void> file({
    required String category,
    required String message,
    String? bookingId,
    String? reportedUserId,
  }) =>
      _api.post('/disputes', body: {
        'category': category,
        'message': message,
        'bookingId': ?bookingId,
        'reportedUserId': ?reportedUserId,
      });
}
