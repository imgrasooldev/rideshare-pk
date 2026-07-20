import '../../../core/network/api_client.dart';
import 'models/vehicle.dart';

class VehiclesRepository {
  VehiclesRepository(this._api);

  final ApiClient _api;

  Future<List<Vehicle>> mine() async {
    final list = await _api.getList('/vehicles/mine');
    return list.map((e) => Vehicle.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Vehicle> create({
    required String make,
    required String model,
    required String plate,
    required int seats,
  }) async {
    final res = await _api.post('/vehicles', body: {
      'make': make,
      'model': model,
      'plate': plate,
      'seats': seats,
      'docUrls': <String>[],
    });
    return Vehicle.fromJson(res);
  }
}
