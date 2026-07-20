import 'package:equatable/equatable.dart';

class Ride extends Equatable {
  const Ride({
    required this.id,
    required this.driverId,
    required this.originLabel,
    required this.destLabel,
    required this.departAt,
    required this.seatsTotal,
    required this.seatsAvailable,
    required this.pricePerSeat,
    required this.ladiesOnly,
    required this.status,
    required this.city,
    this.originLat = 0,
    this.originLng = 0,
    this.destLat = 0,
    this.destLng = 0,
  });

  factory Ride.fromJson(Map<String, dynamic> json) => Ride(
        id: json['id'] as String,
        driverId: json['driverId'] as String,
        originLabel: json['originLabel'] as String,
        destLabel: json['destLabel'] as String,
        departAt: DateTime.parse(json['departAt'] as String).toLocal(),
        seatsTotal: json['seatsTotal'] as int,
        seatsAvailable: json['seatsAvailable'] as int,
        pricePerSeat: json['pricePerSeat'] as int,
        ladiesOnly: json['ladiesOnly'] as bool? ?? false,
        status: json['status'] as String,
        city: json['city'] as String? ?? '',
        originLat: (json['originLat'] as num?)?.toDouble() ?? 0,
        originLng: (json['originLng'] as num?)?.toDouble() ?? 0,
        destLat: (json['destLat'] as num?)?.toDouble() ?? 0,
        destLng: (json['destLng'] as num?)?.toDouble() ?? 0,
      );

  final String id;
  final String driverId;
  final String originLabel;
  final String destLabel;
  final DateTime departAt;
  final int seatsTotal;
  final int seatsAvailable;
  final int pricePerSeat;
  final bool ladiesOnly;
  final String status;
  final String city;
  final double originLat;
  final double originLng;
  final double destLat;
  final double destLng;

  @override
  List<Object?> get props => [
        id, driverId, originLabel, destLabel, departAt, seatsTotal, seatsAvailable,
        pricePerSeat, ladiesOnly, status, city, originLat, originLng, destLat, destLng
      ];
}

class RidePage extends Equatable {
  const RidePage({required this.items, this.nextCursor});

  factory RidePage.fromJson(Map<String, dynamic> json) => RidePage(
        items: (json['items'] as List<dynamic>)
            .map((e) => Ride.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextCursor: json['nextCursor'] as String?,
      );

  final List<Ride> items;
  final String? nextCursor;

  @override
  List<Object?> get props => [items, nextCursor];
}
