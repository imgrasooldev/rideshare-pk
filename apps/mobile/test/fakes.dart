import 'package:rideshare_mobile/core/network/api_exception.dart';
import 'package:rideshare_mobile/features/auth/data/auth_repository.dart';
import 'package:rideshare_mobile/features/auth/data/models/user.dart';
import 'package:rideshare_mobile/features/bookings/data/bookings_repository.dart';
import 'package:rideshare_mobile/features/bookings/data/models/booking.dart';
import 'package:rideshare_mobile/features/categories/data/categories_repository.dart';
import 'package:rideshare_mobile/features/earnings/data/earnings_repository.dart';
import 'package:rideshare_mobile/features/messages/data/messages_repository.dart';
import 'package:rideshare_mobile/features/notifications/data/notifications_repository.dart';
import 'package:rideshare_mobile/features/places/data/places_repository.dart';
import 'package:rideshare_mobile/features/rides/data/models/ride.dart';
import 'package:rideshare_mobile/features/rides/data/rides_repository.dart';
import 'package:rideshare_mobile/features/subscriptions/data/subscriptions_repository.dart';
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
  final registered = <String, String>{}; // email -> password
  String? lastResetToken;

  @override
  Future<String?> requestOtp(String phone) async {
    lastOtpPhone = phone;
    return '123456';
  }

  @override
  Future<User> register({required String email, required String password, String? name}) async {
    if (registered.containsKey(email)) {
      throw const ApiException('An account with this email already exists — log in instead',
          statusCode: 409);
    }
    registered[email] = password;
    sessionUser = User(
      id: 'e1',
      phone: null,
      email: email,
      name: name,
      role: 'rider',
      verified: false,
      city: 'lahore',
    );
    return sessionUser!;
  }

  @override
  Future<User> loginWithEmail(String email, String password) async {
    if (registered[email] != password) {
      throw const ApiException('Incorrect email or password', statusCode: 401);
    }
    sessionUser = User(
        id: 'e1', phone: null, email: email, role: 'rider', verified: false, city: 'lahore');
    return sessionUser!;
  }

  @override
  Future<String?> forgotPassword(String email) async {
    if (!registered.containsKey(email)) return null;
    lastResetToken = 'reset-token-${email.hashCode.abs()}';
    return lastResetToken;
  }

  @override
  Future<void> resetPassword({required String token, required String password}) async {
    if (token != lastResetToken) {
      throw const ApiException('Reset link is invalid or expired — request a new one',
          statusCode: 400);
    }
    final email = registered.keys.first;
    registered[email] = password;
    lastResetToken = null;
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
    String? vehicleType,
    String? vertical,
    String? cursor,
  }) async =>
      RidePage(
        items: rides
            .where((r) => ladiesOnly == null || r.ladiesOnly == ladiesOnly)
            .where((r) => vehicleType == null || r.vehicleType == vehicleType)
            .toList(),
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
    String vehicleType = 'car',
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
      vehicleType: vehicleType,
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
    String vehicleType = 'car',
  }) async {
    final v = Vehicle(
      id: 'v${vehicles.length + 1}',
      make: make,
      model: model,
      plate: plate.toUpperCase(),
      seats: seats,
      verified: false,
      vehicleType: vehicleType,
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

// --- Marketplace repositories added across later slices ---

class FakePlacesRepository implements PlacesRepository {
  @override
  Future<List<Hub>> hubs(String city) async => const [
        Hub('Gulberg (Liberty Market)', 31.5102, 74.3441),
        Hub('DHA Phase 5', 31.4622, 74.4082),
        Hub('Johar Town (Emporium)', 31.4676, 74.2664),
      ];

  @override
  Future<List<City>> cities() async => const [
        City('lahore', 'Lahore', 31.5204, 74.3587),
        City('karachi', 'Karachi', 24.8607, 67.0011),
      ];
}

class FakeNotificationsRepository implements NotificationsRepository {
  @override
  Future<NotificationsPage> fetch() async =>
      const NotificationsPage(items: [], unread: 0);

  @override
  Future<void> markAllRead() async {}

  @override
  Future<void> markRead(String id) async {}
}

class FakeCategoriesRepository implements CategoriesRepository {
  @override
  Future<List<Category>> list() async => const [];
}

class FakeSubscriptionsRepository implements SubscriptionsRepository {
  Subscription _stub(String rideId) => Subscription(
        id: 'sub-1',
        rideId: rideId,
        seats: 1,
        pricePerMonth: 8800,
        status: 'active',
        renewsOn: DateTime(2026, 8, 1),
      );

  @override
  Future<Subscription> subscribe(String rideId, {int seats = 1}) async => _stub(rideId);

  @override
  Future<List<Subscription>> mine() async => const [];

  @override
  Future<Subscription> cancel(String id) async => _stub('ride-1');
}

class FakeMessagesRepository implements MessagesRepository {
  @override
  Future<List<ChatThread>> threads() async => const [];

  @override
  Future<List<Message>> thread(String rideId, String otherId, {int limit = 100}) async =>
      const [];

  @override
  Future<Message> send({
    required String rideId,
    required String recipientId,
    required String body,
  }) async =>
      Message(
        id: 'msg-1',
        rideId: rideId,
        senderId: 'me',
        recipientId: recipientId,
        body: body,
        createdAt: DateTime(2026, 7, 22),
      );

  @override
  Future<int> unreadCount() async => 0;
}

class FakeEarningsRepository implements EarningsRepository {
  @override
  Future<Earnings> fetch() async => const Earnings(
        today: 0,
        thisMonth: 0,
        allTime: 0,
        tripsThisMonth: 0,
        activeSubscribers: 0,
        monthlyRecurring: 0,
        openRides: 0,
        commissionRate: 0.12,
        commissionThisMonth: 0,
        netThisMonth: 0,
        ratingAvg: 0,
        ratingCount: 0,
      );
}
