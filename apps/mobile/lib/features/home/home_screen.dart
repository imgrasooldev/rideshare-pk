import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../app_mode/app_mode_cubit.dart';
import '../auth/data/models/user.dart';
import '../bookings/bloc/my_bookings_bloc.dart';
import '../bookings/presentation/my_bookings_screen.dart';
import '../driver/presentation/driver_shell.dart';
import '../places/bloc/places_cubit.dart';
import '../profile/presentation/profile_screen.dart';
import '../rides/presentation/search_screen.dart';
import '../trust/bloc/verifications_cubit.dart';
import '../vehicles/bloc/vehicles_cubit.dart';
import 'dashboard_screen.dart';

/// Top-level router: the whole shell changes with the app mode. Passenger mode
/// is booking-focused; driver mode (only for driver-role users) is a separate,
/// earning-focused product.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppModeCubit, AppModeState>(
      builder: (context, state) {
        // Driver mode is only reachable by driver-role users.
        if (state.mode == AppMode.driver && user.isDriver) {
          return DriverShell(user: user);
        }
        return PassengerShell(user: user);
      },
    );
  }
}

/// Booking-focused experience: services, search, bookings, profile.
/// Never surfaces driver earnings or business tools.
class PassengerShell extends StatefulWidget {
  const PassengerShell({super.key, required this.user});
  final User user;

  @override
  State<PassengerShell> createState() => _PassengerShellState();
}

class _PassengerShellState extends State<PassengerShell> {
  int _tab = 0;

  // Category filter carried from a dashboard tile into the Search tab.
  String? _searchVertical;
  bool _searchLadies = false;

  @override
  void initState() {
    super.initState();
    // Load the city's hubs/cities from the DB for pickup/drop pickers.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PlacesCubit>().load(widget.user.city);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Tab layout: Home · Search · Bookings · Profile (no driver tools here).
    const homeIndex = 0;
    const searchIndex = 1;
    const bookingsIndex = 2;
    const profileIndex = 3;

    final title = _tab == searchIndex
        ? 'Find a ride'
        : _tab == bookingsIndex
            ? 'My bookings'
            : 'Profile';

    final body = _tab == homeIndex
        ? DashboardScreen(
            user: widget.user,
            onOpenSearch: ({bool ladiesOnly = false, String? vertical}) =>
                setState(() {
                  _tab = searchIndex;
                  _searchVertical = vertical;
                  _searchLadies = ladiesOnly;
                }),
            onOpenBookings: () {
              setState(() => _tab = bookingsIndex);
              context.read<MyBookingsBloc>().add(const MyBookingsRequested());
            },
            onOpenProfile: () {
              setState(() => _tab = profileIndex);
              context.read<VehiclesCubit>().load();
              context.read<VerificationsCubit>().load();
            },
          )
        : _tab == searchIndex
            ? SearchScreen(
                initialVertical: _searchVertical, initialLadiesOnly: _searchLadies)
            : _tab == bookingsIndex
                ? const MyBookingsScreen()
                : ProfileScreen(user: widget.user);

    return Scaffold(
      appBar:
          _tab == homeIndex ? null : AppBar(title: Text(title), centerTitle: false),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() {
            _tab = i;
            // Tapping Search directly clears any category filter carried in.
            if (i == searchIndex) {
              _searchVertical = null;
              _searchLadies = false;
            }
          });
          if (i == bookingsIndex) {
            context.read<MyBookingsBloc>().add(const MyBookingsRequested());
          }
          if (i == profileIndex) {
            context.read<VehiclesCubit>().load();
            context.read<VerificationsCubit>().load();
          }
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
