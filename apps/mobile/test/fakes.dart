import 'package:rideshare_mobile/core/network/api_exception.dart';
import 'package:rideshare_mobile/features/auth/data/auth_repository.dart';
import 'package:rideshare_mobile/features/auth/data/models/user.dart';
import 'package:rideshare_mobile/features/bookings/data/bookings_repository.dart';
import 'package:rideshare_mobile/features/bookings/data/models/booking.dart';
import 'package:rideshare_mobile/features/rides/data/models/ride.dart';
import 'package:rideshare_mobile/features/rides/data/rides_repository.dart';

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
    sessionUser = demoUser;
    return demoUser;
  }

  @override
  Future<User?> restoreSession() async => sessionUser;

  @override
  Future<User> updateProfile({String? name, String? role, String? gender, String? cnic}) async =>
      demoUser;

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
