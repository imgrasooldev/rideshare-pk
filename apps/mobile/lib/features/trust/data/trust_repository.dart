import '../../../core/network/api_client.dart';
import 'models/verification.dart';

class TrustRepository {
  TrustRepository(this._api);

  final ApiClient _api;

  Future<Verification> submit({
    required String type,
    required String docUrl,
    String? vehicleId,
  }) async {
    final res = await _api.post('/verifications', body: {
      'type': type,
      'docUrl': docUrl,
      'vehicleId': ?vehicleId,
    });
    return Verification.fromJson(res);
  }

  Future<List<Verification>> mine() async {
    final list = await _api.getList('/verifications/mine');
    return list.map((e) => Verification.fromJson(e as Map<String, dynamic>)).toList();
  }
}
