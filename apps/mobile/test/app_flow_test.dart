import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rideshare_mobile/app.dart';
import 'package:rideshare_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:rideshare_mobile/features/auth/data/auth_repository.dart';
import 'package:rideshare_mobile/features/bookings/bloc/booking_action_cubit.dart';
import 'package:rideshare_mobile/features/bookings/bloc/my_bookings_bloc.dart';
import 'package:rideshare_mobile/features/bookings/data/bookings_repository.dart';
import 'package:rideshare_mobile/features/rides/bloc/ride_search_bloc.dart';
import 'package:rideshare_mobile/features/rides/data/rides_repository.dart';

import 'fakes.dart';

Widget buildApp({
  required FakeAuthRepository auth,
  required FakeRidesRepository rides,
  required FakeBookingsRepository bookings,
}) {
  return MultiRepositoryProvider(
    providers: [
      RepositoryProvider<AuthRepository>.value(value: auth),
      RepositoryProvider<RidesRepository>.value(value: rides),
      RepositoryProvider<BookingsRepository>.value(value: bookings),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc(auth)..add(const AuthStarted())),
        BlocProvider(create: (_) => RideSearchBloc(rides)),
        BlocProvider(create: (_) => MyBookingsBloc(bookings)),
        BlocProvider(create: (_) => BookingActionCubit(bookings)),
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

    expect(find.textContaining('DHA Phase 5 → Gulberg'), findsOneWidget);
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

  testWidgets('bookings tab lists my booking and cancel updates it', (tester) async {
    await login(tester);
    await tester.tap(find.text('Find rides'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Book a seat'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bookings'));
    await tester.pumpAndSettle();

    expect(find.textContaining('DHA Phase 5 → Gulberg'), findsOneWidget);
    expect(find.text('confirmed'), findsOneWidget);

    await tester.tap(find.text('Cancel booking'));
    await tester.pumpAndSettle();
    expect(find.text('cancelled'), findsOneWidget);
    expect(bookings.bookings.single.status, 'cancelled');
  });
}
