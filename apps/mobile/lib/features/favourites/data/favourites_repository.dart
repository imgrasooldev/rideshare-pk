import '../../../core/network/api_client.dart';

/// A rider-saved origin→destination pair for one-tap re-search.
class SavedRoute {
  const SavedRoute({
    required this.id,
    this.label,
    required this.originLabel,
    this.originLat,
    this.originLng,
    required this.destLabel,
    this.destLat,
    this.destLng,
  });

  factory SavedRoute.fromJson(Map<String, dynamic> j) => SavedRoute(
        id: j['id'] as String,
        label: j['label'] as String?,
        originLabel: j['originLabel'] as String,
        originLat: (j['originLat'] as num?)?.toDouble(),
        originLng: (j['originLng'] as num?)?.toDouble(),
        destLabel: j['destLabel'] as String,
        destLat: (j['destLat'] as num?)?.toDouble(),
        destLng: (j['destLng'] as num?)?.toDouble(),
      );

  final String id;
  final String? label;
  final String originLabel;
  final double? originLat;
  final double? originLng;
  final String destLabel;
  final double? destLat;
  final double? destLng;
}

/// A driver the rider has favourited, with cached rating for display.
class FavouriteDriver {
  const FavouriteDriver({
    required this.driverId,
    this.name,
    this.gender,
    this.ratingAvg,
    this.ratingCount,
  });

  factory FavouriteDriver.fromJson(Map<String, dynamic> j) => FavouriteDriver(
        driverId: j['driverId'] as String,
        name: j['name'] as String?,
        gender: j['gender'] as String?,
        ratingAvg: (j['ratingAvg'] as num?)?.toDouble(),
        ratingCount: (j['ratingCount'] as num?)?.toInt(),
      );

  final String driverId;
  final String? name;
  final String? gender;
  final double? ratingAvg;
  final int? ratingCount;
}

class FavouritesRepository {
  FavouritesRepository(this._api);

  final ApiClient _api;

  // --- Saved routes ---

  Future<List<SavedRoute>> listRoutes() async {
    final rows = await _api.getList('/saved-routes');
    return rows.map((e) => SavedRoute.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SavedRoute> saveRoute({
    String? label,
    required String originLabel,
    double? originLat,
    double? originLng,
    required String destLabel,
    double? destLat,
    double? destLng,
  }) async {
    final json = await _api.post('/saved-routes', body: {
      if (label != null && label.isNotEmpty) 'label': label,
      'originLabel': originLabel,
      'originLat': ?originLat,
      'originLng': ?originLng,
      'destLabel': destLabel,
      'destLat': ?destLat,
      'destLng': ?destLng,
    });
    return SavedRoute.fromJson(json);
  }

  Future<void> deleteRoute(String id) => _api.delete('/saved-routes/$id');

  // --- Favourite drivers ---

  Future<List<FavouriteDriver>> listFavourites() async {
    final rows = await _api.getList('/favourites');
    return rows.map((e) => FavouriteDriver.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Set<String>> favouriteIds() async {
    final list = await listFavourites();
    return list.map((f) => f.driverId).toSet();
  }

  Future<void> addFavourite(String driverId) => _api.post('/favourites/$driverId');

  Future<void> removeFavourite(String driverId) => _api.delete('/favourites/$driverId');
}
