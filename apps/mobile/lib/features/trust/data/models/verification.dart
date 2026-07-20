import 'package:equatable/equatable.dart';

class Verification extends Equatable {
  const Verification({
    required this.id,
    required this.type,
    required this.status,
    required this.createdAt,
    this.notes,
  });

  factory Verification.fromJson(Map<String, dynamic> json) => Verification(
        id: json['id'] as String,
        type: json['type'] as String,
        status: json['status'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        notes: json['notes'] as String?,
      );

  final String id;
  final String type;
  final String status;
  final DateTime createdAt;
  final String? notes;

  @override
  List<Object?> get props => [id, type, status, createdAt, notes];
}
