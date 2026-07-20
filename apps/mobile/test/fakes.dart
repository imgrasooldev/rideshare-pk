import 'package:rideshare_mobile/core/network/api_exception.dart';
import 'package:rideshare_mobile/features/auth/data/auth_repository.dart';
import 'package:rideshare_mobile/features/auth/data/models/user.dart';
import 'package:rideshare_mobile/features/bookings/data/bookings_repository.dart';
import 'package:rideshare_mobile/features/bookings/data/models/booking.dart';
import 'package:rideshare_mobile/features/rides/data/models/ride.dart';
import 'package:rideshare_mobile/features/rides/data/rides_repository.dart';
import 'package:rideshare_mobile/features/trust/data/models/verification.dart';
import 'package:rideshare_mobile/features/trust/data/trust_repository.dart';
import 'package:rideshare_mobile/features/vehicles/data/models/vehicle.dart';
import 'package:rideshare_mobile/features/vehicles/data/vehicles_repository.dart';

/// In-memory doubles implementing the repository contracts — widget and bloc
/// tests exercise real blocs + real screens with no network or storage.
class FakeAuthRepository implements AuthRepository {
  User? sessionUser;
  String? lastOtpPhone;
  bool failVerify = false;

  static const demoUser = User(
    id: 'u1',
    phone: '+923001234567',
    role: 'rider',
    verified: false,
    city: 'lahore',
  );

  static const driverUser = User(
    id: 'u2',
    phone: '+923007654321',
    name: 'Ayesha Driver',
    role: 'driver',
    gender: 'female',
    verified: true,
    city: 'lahore',
    cnicMasked: '*********5671',
  );

  /// The user returned by a successful OTP verify.
  User loginAs = demoUser;

  @override
  Future<String?> requestOtp(String phone) async {
    lastOtpPhone = phone;
    return '123456';
  }

  @override
  Future<User> verifyOtp(String phone, String code) async {
    if (failVerify || code != '123456') {
      throw const ApiException('Invalid or expired code', statusCode: 401);
    }
    sessionUser = loginAs;
    return loginAs;
  }

  @override
  Future<User?> restoreSession() async => sessionUser;

  @override
  Future<User> updateProfile({String? name, String? role, String? gender, String? cnic}) async {
    final base = sessionUser ?? demoUser;
    final updated = User(
      id: base.id,
      phone: base.phone,
      role: role ?? base.role,
      verified: base.verified,
      city: base.city,
      name: name ?? base.name,
      gender: gender ?? base.gender,
      cnicMasked: cnic != null ? '*********${cnic.replaceAll('-', '').substring(9)}' : base.cnicMasked,
    );
    sessionUser = updated;
    return updated;
  }

  @override
  Future<void> logout() async => sessionUser = null;
}

Ride demoRide({String id = 'r1', int seatsAvailable = 3, bool ladiesOnly = false}) => Ride(
      id: id,
      driverId: 'driver-1',
      originLabel: 'DHA Phase 5',
      destLabel: 'Gulberg (Liberty Market)',
      departAt: DateTime.now().add(const Duration(days: 1)),
      seatsTotal: 3,
      seatsAvailable: seatsAvailable,
      pricePerSeat: 250,
      ladiesOnly: ladiesOnly,
      status: 'open',
      city: 'lahore',
    );

class FakeRidesRepository implements RidesRepository {
  List<Ride> rides = [demoRide()];
  final List<Ride> posted = [];

  @override
  Future<RidePage> search({
    required Hub pickup,
    required Hub drop,
    required DateTime departAfter,
    required DateTime departBefore,
    double radiusKm = 3,
    bool? ladiesOnly,
    String? cursor,
  }) async =>
      RidePage(
        items: rides.where((r) => ladiesOnly == null || r.ladiesOnly == ladiesOnly).toList(),
      );

  @override
  Future<Ride> getById(String id) async => rides.firstWhere((r) => r.id == id);

  @override
  Future<Ride> postRide({
    required Hub origin,
    required Hub dest,
    required DateTime departAt,
    required List<int> recurringDays,
    required int seatsTotal,
    required int pricePerSeat,
    bool ladiesOnly = false,
  }) async {
    final ride = Ride(
      id: 'posted-${posted.length + 1}',
      driverId: 'u2',
      originLabel: origin.label,
      destLabel: dest.label,
      departAt: departAt,
      seatsTotal: seatsTotal,
      seatsAvailable: seatsTotal,
      pricePerSeat: pricePerSeat,
      ladiesOnly: ladiesOnly,
      status: 'open',
      city: 'lahore',
    );
    posted.add(ride);
    return ride;
  }

  @override
  Future<RidePage> myRides({String? cursor}) async => RidePage(items: posted.reversed.toList());
}

class FakeVehiclesRepository implements VehiclesRepository {
  final List<Vehicle> vehicles = [];

  @override
  Future<List<Vehicle>> mine() async => List.of(vehicles);

  @override
  Future<Vehicle> create({
    required String make,
    required String model,
    required String plate,
    required int seats,
  }) async {
    final v = Vehicle(
      id: 'v${vehicles.length + 1}',
      make: make,
      model: model,
      plate: plate.toUpperCase(),
      seats: seats,
      verified: false,
    );
    vehicles.add(v);
    return v;
  }
}

class FakeTrustRepository implements TrustRepository {
  final List<Verification> submissions = [];

  @override
  Future<Verification> submit({
    required String type,
    required String docUrl,
    String? vehicleId,
  }) async {
    final v = Verification(
      id: 'ver${submissions.length + 1}',
      type: type,
      status: 'pending',
      createdAt: DateTime.now(),
    );
    submissions.add(v);
    return v;
  }

  @override
  Future<List<Verification>> mine() async => submissions.reversed.toList();
}

class FakeBookingsRepository implements BookingsRepository {
  final List<Booking> bookings = [];
  final Set<String> seenKeys = {};
  int bookCalls = 0;

  @override
  String newIdempotencyKey() => 'test-key-${bookCalls + 1}';

  @override
  Future<Booking> book({
    required String rideId,
    required int seats,
    required String idempotencyKey,
  }) async {
    bookCalls++;
    if (seenKeys.contains(idempotencyKey)) return bookings.last;
    seenKeys.add(idempotencyKey);
    final booking = Booking(
      id: 'b${bookings.length + 1}',
      rideId: rideId,
      seats: seats,
      status: 'confirmed',
      createdAt: DateTime.now(),
      originLabel: 'DHA Phase 5',
      destLabel: 'Gulberg (Liberty Market)',
      departAt: DateTime.now().add(const Duration(days: 1)),
      pricePerSeat: 250,
    );
    bookings.add(booking);
    return booking;
  }

  @override
  Future<Booking> cancel(String bookingId) async {
    final i = bookings.indexWhere((b) => b.id == bookingId);
    final b = bookings[i];
    final cancelled = Booking(
      id: b.id,
      rideId: b.rideId,
      seats: b.seats,
      status: 'cancelled',
      createdAt: b.createdAt,
      originLabel: b.originLabel,
      destLabel: b.destLabel,
      departAt: b.departAt,
      pricePerSeat: b.pricePerSeat,
    );
    bookings[i] = cancelled;
    return cancelled;
  }

  @override
  Future<({List<Booking> items, String? nextCursor})> mine({String? cursor}) async =>
      (items: bookings.reversed.toList(), nextCursor: null);
}
