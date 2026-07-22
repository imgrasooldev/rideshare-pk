import 'package:equatable/equatable.dart';

class User extends Equatable {
  const User({
    required this.id,
    required this.phone,
    required this.role,
    required this.verified,
    required this.city,
    this.email,
    this.name,
    this.gender,
    this.cnicMasked,
    this.emergencyPhone,
    this.isOnline = true,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        phone: json['phone'] as String?,
        role: json['role'] as String? ?? 'rider',
        verified: json['verified'] as bool? ?? false,
        city: json['city'] as String? ?? '',
        email: json['email'] as String?,
        name: json['name'] as String?,
        gender: json['gender'] as String?,
        cnicMasked: json['cnicMasked'] as String?,
        emergencyPhone: json['emergencyPhone'] as String?,
        isOnline: json['isOnline'] as bool? ?? true,
      );

  final String id;
  final String? phone;
  final String? email;
  final String role;
  final bool verified;
  final String city;
  final String? name;
  final String? gender;
  final String? cnicMasked;
  final String? emergencyPhone;
  final bool isOnline;

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone': phone,
        'role': role,
        'verified': verified,
        'city': city,
        'name': name,
        'gender': gender,
        'cnicMasked': cnicMasked,
        'emergencyPhone': emergencyPhone,
        'isOnline': isOnline,
      };

  bool get isDriver => role == 'driver' || role == 'both';

  /// Best display handle for headers/avatars.
  String get handle => name ?? phone ?? email ?? 'You';

  @override
  List<Object?> get props => [
        id, phone, email, role, verified, city, name, gender, cnicMasked,
        emergencyPhone, isOnline
      ];
}
