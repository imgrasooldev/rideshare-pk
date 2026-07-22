import '../../../core/network/api_client.dart';
import '../../rides/data/rides_repository.dart' show Hub;

class City {
  const City(this.slug, this.name, this.centerLat, this.centerLng);
  final String slug;
  final String name;
  final double centerLat;
  final double centerLng;
}

/// Driving distance/ETA between two points (with a polyline).
class RouteInfo {
  const RouteInfo({required this.distanceKm, required this.durationMin, this.points = const []});
  factory RouteInfo.fromJson(Map<String, dynamic> j) => RouteInfo(
        distanceKm: (j['distanceKm'] as num?)?.toDouble() ?? 0,
        durationMin: (j['durationMin'] as num?)?.toInt() ?? 0,
        points: ((j['points'] as List<dynamic>?) ?? [])
            .map((p) => ((p as List).map((n) => (n as num).toDouble()).toList()))
            .toList(),
      );
  final double distanceKm;
  final int durationMin;
  final List<List<double>> points; // [[lat, lng], ...]
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

  /// Free-text address search (OpenStreetMap geocoding via the backend).
  Future<List<Hub>> search(String query, {String? city}) async {
    if (query.trim().length < 3) return [];
    final res = await _api.getList('/places/search', query: {
      'q': query.trim(),
      'city': ?city,
    });
    return res
        .map((e) => Hub(
              e['label'] as String,
              (e['lat'] as num).toDouble(),
              (e['lng'] as num).toDouble(),
            ))
        .toList();
  }

  Future<RouteInfo> route(Hub from, Hub to) async => RouteInfo.fromJson(
        await _api.get('/places/route', query: {
          'fromLat': from.lat,
          'fromLng': from.lng,
          'toLat': to.lat,
          'toLng': to.lng,
        }),
      );

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
