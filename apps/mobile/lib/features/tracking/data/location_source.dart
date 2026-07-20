import 'package:geolocator/geolocator.dart';

/// Where the driver's position comes from. Device GPS in the real world; a
/// simulated route when GPS is unavailable/denied (desktop demos, emulators).
abstract interface class LocationSource {
  Future<({double lat, double lng})?> next();
}

class GpsLocationSource implements LocationSource {
  bool _ready = false;

  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    _ready = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
    return _ready;
  }

  @override
  Future<({double lat, double lng})?> next() async {
    if (!_ready && !await ensurePermission()) return null;
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 5));
      return (lat: p.latitude, lng: p.longitude);
    } catch (_) {
      return null;
    }
  }
}

/// Straight-line interpolation origin→destination — keeps demos honest about
/// what tracking looks like without needing a moving phone.
class DemoRouteSource implements LocationSource {
  DemoRouteSource({
    required this.fromLat,
    required this.fromLng,
    required this.toLat,
    required this.toLng,
    this.steps = 60,
  });

  final double fromLat;
  final double fromLng;
  final double toLat;
  final double toLng;
  final int steps;
  int _i = 0;

  @override
  Future<({double lat, double lng})?> next() async {
    final t = (_i / steps).clamp(0.0, 1.0);
    if (_i < steps) _i++;
    return (
      lat: fromLat + (toLat - fromLat) * t,
      lng: fromLng + (toLng - fromLng) * t,
    );
  }
}
