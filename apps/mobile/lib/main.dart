import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/push/push_service.dart';
import 'features/app_mode/app_mode_cubit.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/bookings/bloc/booking_action_cubit.dart';
import 'features/bookings/bloc/my_bookings_bloc.dart';
import 'features/bookings/bloc/requests_cubit.dart';
import 'features/bookings/data/bookings_repository.dart';
import 'features/categories/bloc/categories_cubit.dart';
import 'features/categories/data/categories_repository.dart';
import 'features/disputes/data/disputes_repository.dart';
import 'features/driver/bloc/my_rides_cubit.dart';
import 'features/driver/bloc/post_ride_cubit.dart';
import 'features/earnings/bloc/earnings_cubit.dart';
import 'features/earnings/data/earnings_repository.dart';
import 'features/messages/bloc/messages_unread_cubit.dart';
import 'features/messages/bloc/threads_cubit.dart';
import 'features/messages/data/messages_repository.dart';
import 'features/notifications/bloc/notifications_cubit.dart';
import 'features/notifications/data/notifications_repository.dart';
import 'features/places/bloc/places_cubit.dart';
import 'features/places/data/places_repository.dart';
import 'features/profile/bloc/profile_cubit.dart';
import 'features/referrals/data/referrals_repository.dart';
import 'features/settings/locale_cubit.dart';
import 'features/rides/bloc/ride_search_bloc.dart';
import 'features/rides/data/rides_repository.dart';
import 'features/safety/data/blocks_repository.dart';
import 'features/subscriptions/bloc/subscriptions_cubit.dart';
import 'features/subscriptions/data/subscriptions_repository.dart';
import 'features/tracking/data/tracking_repository.dart';
import 'features/trust/bloc/verifications_cubit.dart';
import 'features/trust/data/trust_repository.dart';
import 'features/vehicles/bloc/vehicles_cubit.dart';
import 'features/vehicles/data/vehicles_repository.dart';
import 'features/wallet/bloc/wallet_cubit.dart';
import 'features/wallet/data/wallet_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Semantics on from the start: screen-reader accessible, and testable
  // through the accessibility tree on web.
  SemanticsBinding.instance.ensureSemantics();

  // Composition root: storage → api client → repositories → blocs.
  final storage = TokenStorage();
  final api = ApiClient(storage);
  final authRepository = AuthRepository(api, storage);

  // Firebase Cloud Messaging (best-effort; a missing config never blocks boot).
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  } catch (_) {
    /* push unavailable — the app runs fine without it */
  }
  final push = PushService(api);

  // Own the AuthBloc here so the device can register for push on login.
  final authBloc = AuthBloc(authRepository)..add(const AuthStarted());
  api.onSessionExpired = () => authBloc.add(const AuthLogoutRequested());
  authBloc.stream.listen((state) {
    if (state is AuthAuthenticated) push.register();
  });

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider(create: (_) => RidesRepository(api)),
        RepositoryProvider(create: (_) => PlacesRepository(api)),
        RepositoryProvider(create: (_) => NotificationsRepository(api)),
        RepositoryProvider(create: (_) => SubscriptionsRepository(api)),
        RepositoryProvider(create: (_) => EarningsRepository(api)),
        RepositoryProvider(create: (_) => WalletRepository(api)),
        RepositoryProvider(create: (_) => CategoriesRepository(api)),
        RepositoryProvider(create: (_) => MessagesRepository(api)),
        RepositoryProvider(create: (_) => BookingsRepository(api)),
        RepositoryProvider(create: (_) => VehiclesRepository(api)),
        RepositoryProvider(create: (_) => TrustRepository(api)),
        RepositoryProvider(create: (_) => TrackingRepository(api, storage)),
        RepositoryProvider(create: (_) => ReferralsRepository(api)),
        RepositoryProvider(create: (_) => DisputesRepository(api)),
        RepositoryProvider(create: (_) => BlocksRepository(api)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: authBloc),
          BlocProvider(create: (context) => LocaleCubit()),
          BlocProvider(create: (context) => AppModeCubit()),
          BlocProvider(create: (context) => RideSearchBloc(context.read<RidesRepository>())),
          BlocProvider(create: (context) => PlacesCubit(context.read<PlacesRepository>())),
          BlocProvider(
              create: (context) => NotificationsCubit(context.read<NotificationsRepository>())),
          BlocProvider(
              create: (context) => SubscriptionsCubit(context.read<SubscriptionsRepository>())),
          BlocProvider(create: (context) => EarningsCubit(context.read<EarningsRepository>())),
          BlocProvider(create: (context) => WalletCubit(context.read<WalletRepository>())),
          BlocProvider(
              create: (context) =>
                  CategoriesCubit(context.read<CategoriesRepository>())..load()),
          BlocProvider(create: (context) => ThreadsCubit(context.read<MessagesRepository>())),
          BlocProvider(
              create: (context) => MessagesUnreadCubit(context.read<MessagesRepository>())),
          BlocProvider(create: (context) => MyBookingsBloc(context.read<BookingsRepository>())),
          BlocProvider(create: (context) => BookingActionCubit(context.read<BookingsRepository>())),
          BlocProvider(create: (context) => RequestsCubit(context.read<BookingsRepository>())),
          BlocProvider(create: (context) => MyRidesCubit(context.read<RidesRepository>())),
          BlocProvider(create: (context) => PostRideCubit(context.read<RidesRepository>())),
          BlocProvider(create: (context) => ProfileCubit(context.read<AuthRepository>())),
          BlocProvider(create: (context) => VehiclesCubit(context.read<VehiclesRepository>())),
          BlocProvider(create: (context) => VerificationsCubit(context.read<TrustRepository>())),
        ],
        child: const RideshareApp(),
      ),
    ),
  );
}
