import '../../../core/network/api_client.dart';
import '../../rides/data/rides_repository.dart' show Hub;

class City {
  const City(this.slug, this.name, this.centerLat, this.centerLng);
  final String slug;
  final String name;
  final double centerLat;
  final double centerLng;
}

/// Loads dynamic locations from the backend (Postgres): cities and their curated
/// pickup/drop hubs. Replaces the old hardcoded Lahore-only list.
class PlacesRepository {
  PlacesRepository(this._api);
  final ApiClient _api;

  Future<List<Hub>> hubs(String city) async {
    final res = await _api.getList('/hubs', query: {'city': city});
    return res
        .map((e) => Hub(
              e['label'] as String,
              (e['lat'] as num).toDouble(),
              (e['lng'] as num).toDouble(),
            ))
        .toList();
  }

  Future<List<City>> cities() async {
    final res = await _api.getList('/cities');
    return res
        .map((e) => City(
              e['slug'] as String,
              e['name'] as String,
              (e['centerLat'] as num).toDouble(),
              (e['centerLng'] as num).toDouble(),
            ))
        .toList();
  }
}
