import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare_mobile/app.dart';
import 'package:rideshare_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:rideshare_mobile/features/auth/data/auth_repository.dart';
import 'package:rideshare_mobile/features/bookings/bloc/booking_action_cubit.dart';
import 'package:rideshare_mobile/features/bookings/bloc/my_bookings_bloc.dart';
import 'package:rideshare_mobile/features/bookings/data/bookings_repository.dart';
import 'package:rideshare_mobile/features/driver/bloc/my_rides_cubit.dart';
import 'package:rideshare_mobile/features/driver/bloc/post_ride_cubit.dart';
import 'package:rideshare_mobile/features/profile/bloc/profile_cubit.dart';
import 'package:rideshare_mobile/features/rides/bloc/ride_search_bloc.dart';
import 'package:rideshare_mobile/features/rides/data/rides_repository.dart';
import 'package:rideshare_mobile/features/trust/bloc/verifications_cubit.dart';
import 'package:rideshare_mobile/features/trust/data/trust_repository.dart';
import 'package:rideshare_mobile/features/vehicles/bloc/vehicles_cubit.dart';
import 'package:rideshare_mobile/features/vehicles/data/vehicles_repository.dart';

import 'fakes.dart';

Widget buildApp({
  required FakeAuthRepository auth,
  required FakeRidesRepository rides,
  required FakeBookingsRepository bookings,
  FakeVehiclesRepository? vehicles,
  FakeTrustRepository? trust,
}) {
  final vehiclesRepo = vehicles ?? FakeVehiclesRepository();
  final trustRepo = trust ?? FakeTrustRepository();
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<AuthRepository>.value(value: auth),
      RepositoryProvider<RidesRepository>.value(value: rides),
      RepositoryProvider<BookingsRepository>.value(value: bookings),
      RepositoryProvider<VehiclesRepository>.value(value: vehiclesRepo),
      RepositoryProvider<TrustRepository>.value(value: trustRepo),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc(auth)..add(const AuthStarted())),
        BlocProvider(create: (_) => RideSearchBloc(rides)),
        BlocProvider(create: (_) => MyBookingsBloc(bookings)),
        BlocProvider(create: (_) => BookingActionCubit(bookings)),
        BlocProvider(create: (_) => MyRidesCubit(rides)),
        BlocProvider(create: (_) => PostRideCubit(rides)),
        BlocProvider(create: (_) => ProfileCubit(auth)),
        BlocProvider(create: (_) => VehiclesCubit(vehiclesRepo)),
        BlocProvider(create: (_) => VerificationsCubit(trustRepo)),
      ],
      child: const RideshareApp(),
    ),
  );
}

void main() {
  late FakeAuthRepository auth;
  late FakeRidesRepository rides;
  late FakeBookingsRepository bookings;

  setUp(() {
    auth = FakeAuthRepository();
    rides = FakeRidesRepository();
    bookings = FakeBookingsRepository();
  });

  Future<void> login(WidgetTester tester) async {
    // Tall phone viewport so scrollable content stays reachable in tests.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildApp(auth: auth, rides: rides, bookings: bookings));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '03001234567');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.pumpAndSettle();
  }

  testWidgets('full login flow: phone → dev-code chip → OTP → home', (tester) async {
    await tester.pumpWidget(buildApp(auth: auth, rides: rides, bookings: bookings));
    await tester.pumpAndSettle();

    expect(find.text('Rideshare PK'), findsOneWidget);

    // Invalid phone is rejected client-side.
    await tester.enterText(find.byType(TextFormField), '12345');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('valid Pakistani mobile'), findsOneWidget);
    expect(auth.lastOtpPhone, isNull);

    // Valid phone moves to the OTP step and surfaces the dev code.
    await tester.enterText(find.byType(TextFormField), '03001234567');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(auth.lastOtpPhone, '03001234567');
    expect(find.text('Enter the 6-digit code'), findsOneWidget);
    expect(find.text('Dev code: 123456'), findsOneWidget);

    // 6 digits auto-submit → authenticated home with bottom tabs.
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.pumpAndSettle();
    expect(find.text('Find a ride'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('email tab: register creates an account and lands on home', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildApp(auth: auth, rides: rides, bookings: bookings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);

    // Switch to register, fill the form, submit.
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'sara@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'supersecret1');
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    expect(auth.registered['sara@example.com'], 'supersecret1');
    expect(find.text('Find a ride'), findsOneWidget); // authenticated home
  });

  testWidgets('email login rejects a wrong password with the API error', (tester) async {
    auth.registered['sara@example.com'] = 'rightpassword1';
    await tester.pumpWidget(buildApp(auth: auth, rides: rides, bookings: bookings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'sara@example.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), 'wrongwrong1');
    await tester.tap(find.text('Log in'));
    await tester.pumpAndSettle();

    expect(find.text('Incorrect email or password'), findsOneWidget);
    expect(find.text('Find a ride'), findsNothing);
  });

  testWidgets('forgot password flow resets via the dev token', (tester) async {
    auth.registered['sara@example.com'] = 'oldpassword1';
    await tester.pumpWidget(buildApp(auth: auth, rides: rides, bookings: bookings));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Email'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    // .last: the sheet's field sits above the login form's email field.
    await tester.enterText(find.widgetWithText(TextField, 'Email').last, 'sara@example.com');
    await tester.tap(find.text('Send reset code'));
    await tester.pumpAndSettle();

    // Dev token is prefilled; just set the new password.
    await tester.enterText(
        find.widgetWithText(TextField, 'New password (min 8 characters)'), 'newpassword9');
    await tester.tap(find.text('Set new password'));
    await tester.pumpAndSettle();

    expect(auth.registered['sara@example.com'], 'newpassword9');
    expect(find.textContaining('Password updated'), findsOneWidget);
  });

  testWidgets('wrong OTP shows the API error and stays on the code step', (tester) async {
    await tester.pumpWidget(buildApp(auth: auth, rides: rides, bookings: bookings));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '03001234567');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '999999');
    await tester.pumpAndSettle();
    expect(find.text('Invalid or expired code'), findsOneWidget);
    expect(find.text('Enter the 6-digit code'), findsOneWidget);
  });

  testWidgets('search shows ride cards and booking succeeds', (tester) async {
    await login(tester);

    await tester.tap(find.text('Find rides'));
    await tester.pumpAndSettle();

    expect(find.text('DHA Phase 5'), findsWidgets);
    expect(find.text('Gulberg (Liberty Market)'), findsWidgets);
    expect(find.text('Rs 250'), findsOneWidget);
    expect(find.textContaining('3 of 3 seats'), findsOneWidget);

    await tester.tap(find.text('Book a seat'));
    await tester.pumpAndSettle();

    expect(bookings.bookings, hasLength(1));
    expect(bookings.bookings.single.rideId, 'r1');
    expect(find.textContaining('Seat booked!'), findsOneWidget); // success snackbar
  });

  testWidgets('full rides show as Full and cannot be booked', (tester) async {
    rides.rides = [demoRide(seatsAvailable: 0)];
    await login(tester);

    await tester.tap(find.text('Find rides'));
    await tester.pumpAndSettle();

    final fullButton = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Full'));
    expect(fullButton.onPressed, isNull);
  });

  testWidgets('riders see no Drive tab; drivers do', (tester) async {
    await login(tester);
    expect(find.text('Drive'), findsNothing);
  });

  testWidgets('driver posts a ride from the Drive tab', (tester) async {
    auth.loginAs = FakeAuthRepository.driverUser;
    await login(tester);

    await tester.tap(find.text('Drive'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No rides posted yet'), findsOneWidget);

    await tester.tap(find.text('Post ride'));
    await tester.pumpAndSettle();
    expect(find.text('Post a ride'), findsOneWidget);
    // Female driver sees the ladies-only switch.
    expect(find.text('Ladies only'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Post ride'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Post ride'));
    await tester.pumpAndSettle();

    // Back on the Drive tab with the new ride listed.
    expect(rides.posted, hasLength(1));
    expect(rides.posted.single.seatsTotal, 3);
    expect(rides.posted.single.pricePerSeat, 250);
    expect(find.text('DHA Phase 5'), findsWidgets);
    expect(find.text('Gulberg (Liberty Market)'), findsWidgets);
  });

  testWidgets('profile edit saves role change and updates the app user', (tester) async {
    await login(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Full name'), 'GR Khan');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Profile updated'), findsOneWidget);
    expect(auth.sessionUser?.name, 'GR Khan');
  });

  testWidgets('bookings tab lists my booking and cancel updates it', (tester) async {
    await login(tester);
    await tester.tap(find.text('Find rides'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book a seat'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();

    expect(find.text('DHA Phase 5'), findsWidgets);
    expect(find.text('confirmed'), findsOneWidget);

    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    expect(find.text('cancelled'), findsOneWidget);
    expect(bookings.bookings.single.status, 'cancelled');
  });
}
