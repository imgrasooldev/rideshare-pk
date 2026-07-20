import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/storage/token_storage.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/bookings/bloc/booking_action_cubit.dart';
import 'features/bookings/bloc/my_bookings_bloc.dart';
import 'features/bookings/data/bookings_repository.dart';
import 'features/driver/bloc/my_rides_cubit.dart';
import 'features/driver/bloc/post_ride_cubit.dart';
import 'features/profile/bloc/profile_cubit.dart';
import 'features/rides/bloc/ride_search_bloc.dart';
import 'features/rides/data/rides_repository.dart';
import 'features/tracking/data/tracking_repository.dart';
import 'features/trust/bloc/verifications_cubit.dart';
import 'features/trust/data/trust_repository.dart';
import 'features/vehicles/bloc/vehicles_cubit.dart';
import 'features/vehicles/data/vehicles_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Semantics on from the start: screen-reader accessible, and testable
  // through the accessibility tree on web.
  SemanticsBinding.instance.ensureSemantics();

  // Composition root: storage → api client → repositories → blocs.
  final storage = TokenStorage();
  final api = ApiClient(storage);
  final authRepository = AuthRepository(api, storage);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider(create: (_) => RidesRepository(api)),
        RepositoryProvider(create: (_) => BookingsRepository(api)),
        RepositoryProvider(create: (_) => VehiclesRepository(api)),
        RepositoryProvider(create: (_) => TrustRepository(api)),
        RepositoryProvider(create: (_) => TrackingRepository(api, storage)),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) {
              final bloc = AuthBloc(context.read<AuthRepository>())..add(const AuthStarted());
              // A failed token refresh anywhere logs the user out globally.
              api.onSessionExpired = () => bloc.add(const AuthLogoutRequested());
              return bloc;
            },
          ),
          BlocProvider(create: (context) => RideSearchBloc(context.read<RidesRepository>())),
          BlocProvider(create: (context) => MyBookingsBloc(context.read<BookingsRepository>())),
          BlocProvider(create: (context) => BookingActionCubit(context.read<BookingsRepository>())),
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
