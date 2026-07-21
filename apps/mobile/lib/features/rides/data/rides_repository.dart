import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import 'models/ride.dart';

/// Marketplace vehicle types — anyone can list a car, bike, Hiace, or minivan.
const vehicleTypes = ['car', 'bike', 'hiace', 'minivan'];

IconData vehicleTypeIcon(String type) => switch (type) {
      'bike' => Icons.two_wheeler_rounded,
      'hiace' => Icons.airport_shuttle_rounded,
      'minivan' => Icons.directions_bus_rounded,
      _ => Icons.directions_car_rounded,
    };

String vehicleTypeLabel(String type) => switch (type) {
      'bike' => 'Bike',
      'hiace' => 'Hiace',
      'minivan' => 'Minivan',
      _ => 'Car',
    };

/// A named pickup/drop point. MVP uses curated Lahore hubs; the map-based
/// picker replaces this list without touching blocs (repository pattern).
class Hub {
  const Hub(this.label, this.lat, this.lng);
  final String label;
  final double lat;
  final double lng;
}

const lahoreHubs = [
  Hub('Gulberg (Liberty Market)', 31.5102, 74.3441),
  Hub('DHA Phase 5', 31.4622, 74.4082),
  Hub('Johar Town (Emporium)', 31.4676, 74.2664),
  Hub('Model Town Link Rd', 31.4811, 74.3242),
  Hub('Allama Iqbal Intl Airport', 31.5216, 74.4036),
  Hub('Bahria Town Lahore', 31.3670, 74.1845),
  Hub('Shahdara Chowk', 31.5925, 74.3095),
  Hub('Kalma Chowk (Ferozepur Rd)', 31.5040, 74.3320),
];

class RidesRepository {
  RidesRepository(this._api);

  final ApiClient _api;

  Future<RidePage> search({
    required Hub pickup,
    required Hub drop,
    required DateTime departAfter,
    required DateTime departBefore,
    double radiusKm = 3,
    bool? ladiesOnly,
    String? vehicleType,
    String? vertical,
    String? cursor,
  }) async {
    final res = await _api.get('/rides/search', query: {
      'vehicleType': ?vehicleType,
      'vertical': ?vertical,
      'pickupLat': pickup.lat,
      'pickupLng': pickup.lng,
      'dropLat': drop.lat,
      'dropLng': drop.lng,
      'radiusKm': radiusKm,
      'departAfter': departAfter.toUtc().toIso8601String(),
      'departBefore': departBefore.toUtc().toIso8601String(),
      'ladiesOnly': ?ladiesOnly?.toString(),
      'cursor': ?cursor,
    });
    return RidePage.fromJson(res);
  }

  Future<Ride> getById(String id) async => Ride.fromJson(await _api.get('/rides/$id'));

  Future<Ride> postRide({
    required Hub origin,
    required Hub dest,
    required DateTime departAt,
    required List<int> recurringDays,
    required int seatsTotal,
    required int pricePerSeat,
    String vehicleType = 'car',
    bool ladiesOnly = false,
  }) async {
    final res = await _api.post('/rides', body: {
      'vehicleType': vehicleType,
      'originLabel': origin.label,
      'originLat': origin.lat,
      'originLng': origin.lng,
      'destLabel': dest.label,
      'destLat': dest.lat,
      'destLng': dest.lng,
      'departAt': departAt.toUtc().toIso8601String(),
      'recurringDays': recurringDays,
      'seatsTotal': seatsTotal,
      'pricePerSeat': pricePerSeat,
      'ladiesOnly': ladiesOnly,
    });
    return Ride.fromJson(res);
  }

  Future<RidePage> myRides({String? cursor}) async =>
      RidePage.fromJson(await _api.get('/rides/mine', query: {'cursor': ?cursor}));
}
