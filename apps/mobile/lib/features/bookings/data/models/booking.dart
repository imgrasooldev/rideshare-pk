import 'package:equatable/equatable.dart';

class Booking extends Equatable {
  const Booking({
    required this.id,
    required this.rideId,
    required this.seats,
    required this.status,
    required this.createdAt,
    this.originLabel,
    this.destLabel,
    this.departAt,
    this.pricePerSeat,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final ride = json['ride'] as Map<String, dynamic>?;
    return Booking(
      id: json['id'] as String,
      rideId: json['rideId'] as String,
      seats: json['seats'] as int,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      originLabel: ride?['originLabel'] as String?,
      destLabel: ride?['destLabel'] as String?,
      departAt: ride?['departAt'] != null
          ? DateTime.parse(ride!['departAt'] as String).toLocal()
          : null,
      pricePerSeat: ride?['pricePerSeat'] as int?,
    );
  }

  final String id;
  final String rideId;
  final int seats;
  final String status;
  final DateTime createdAt;
  final String? originLabel;
  final String? destLabel;
  final DateTime? departAt;
  final int? pricePerSeat;

  bool get isActive => status == 'confirmed' || status == 'requested';

  @override
  List<Object?> get props =>
      [id, rideId, seats, status, createdAt, originLabel, destLabel, departAt, pricePerSeat];
}
