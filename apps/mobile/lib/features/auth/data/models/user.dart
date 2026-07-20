import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.phone,
    required this.role,
    required this.verified,
    required this.city,
    this.name,
    this.gender,
    this.cnicMasked,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        phone: json['phone'] as String,
        role: json['role'] as String? ?? 'rider',
        verified: json['verified'] as bool? ?? false,
        city: json['city'] as String? ?? '',
        name: json['name'] as String?,
        gender: json['gender'] as String?,
        cnicMasked: json['cnicMasked'] as String?,
      );

  final String id;
  final String phone;
  final String role;
  final bool verified;
  final String city;
  final String? name;
  final String? gender;
  final String? cnicMasked;

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'role': role,
        'verified': verified,
        'city': city,
        'name': name,
        'gender': gender,
        'cnicMasked': cnicMasked,
      };

  bool get isDriver => role == 'driver' || role == 'both';

  @override
  List<Object?> get props => [id, phone, role, verified, city, name, gender, cnicMasked];
}
