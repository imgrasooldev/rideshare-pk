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
import 'features/rides/bloc/ride_search_bloc.dart';
import 'features/rides/data/rides_repository.dart';

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
        ],
        child: const RideshareApp(),
      ),
    ),
  );
}
