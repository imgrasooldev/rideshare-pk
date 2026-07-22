import 'package:equatable/equatable.dart';

/// A pending seat request as the driver sees it in their dispatch inbox.
class SeatRequest extends Equatable {
  const SeatRequest({
    required this.id,
    required this.rideId,
    required this.seats,
    required this.status,
    required this.createdAt,
    this.riderName,
    this.originLabel,
    this.destLabel,
    this.departAt,
    this.pricePerSeat,
    this.offeredPrice,
  });

  factory SeatRequest.fromJson(Map<String, dynamic> json) {
    final ride = json['ride'] as Map<String, dynamic>?;
    return SeatRequest(
      id: json['id'] as String,
      rideId: json['rideId'] as String,
      seats: json['seats'] as int? ?? 1,
      status: json['status'] as String? ?? 'requested',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      riderName: json['riderName'] as String?,
      originLabel: ride?['originLabel'] as String?,
      destLabel: ride?['destLabel'] as String?,
      departAt: ride?['departAt'] != null
          ? DateTime.tryParse(ride!['departAt'] as String)?.toLocal()
          : null,
      pricePerSeat: (ride?['pricePerSeat'] as num?)?.toInt(),
      offeredPrice: (json['offeredPrice'] as num?)?.toInt(),
    );
  }

  final String id;
  final String rideId;
  final int seats;
  final String status; // 'requested' | 'countered'
  final DateTime createdAt;
  final String? riderName;
  final String? originLabel;
  final String? destLabel;
  final DateTime? departAt;
  final int? pricePerSeat;
  final int? offeredPrice;

  int? get effectivePrice => offeredPrice ?? pricePerSeat;

  @override
  List<Object?> get props => [id, status, seats, offeredPrice, createdAt];
}
