import 'package:equatable/equatable.dart';

class Vehicle extends Equatable {
  const Vehicle({
    required this.id,
    required this.make,
    required this.model,
    required this.plate,
    required this.seats,
    required this.verified,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as String,
        make: json['make'] as String,
        model: json['model'] as String,
        plate: json['plate'] as String,
        seats: json['seats'] as int,
        verified: json['verified'] as bool? ?? false,
      );

  final String id;
  final String make;
  final String model;
  final String plate;
  final int seats;
  final bool verified;

  @override
  List<Object?> get props => [id, make, model, plate, seats, verified];
}
