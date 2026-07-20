import 'package:equatable/equatable.dart';

class Trip extends Equatable {
  const Trip({required this.id, required this.rideId, required this.liveStatus, required this.shareToken});

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        rideId: json['rideId'] as String,
        liveStatus: json['liveStatus'] as String,
        shareToken: json['shareToken'] as String,
      );

  final String id;
  final String rideId;
  final String liveStatus;
  final String shareToken;

  @override
  List<Object?> get props => [id, rideId, liveStatus, shareToken];
}

class LivePoint extends Equatable {
  const LivePoint({required this.lat, required this.lng, required this.at});

  factory LivePoint.fromJson(Map<String, dynamic> json) => LivePoint(
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
      );

  final double lat;
  final double lng;
  final DateTime at;

  @override
  List<Object?> get props => [lat, lng, at];
}

sealed class TrackingEvent {
  const TrackingEvent();
}

final class TrackingLocation extends TrackingEvent {
  const TrackingLocation(this.point);
  final LivePoint point;
}

final class TrackingEnded extends TrackingEvent {
  const TrackingEnded();
}

final class TrackingError extends TrackingEvent {
  const TrackingError(this.message);
  final String message;
}
