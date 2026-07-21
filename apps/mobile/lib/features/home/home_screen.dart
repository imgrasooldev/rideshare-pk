import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/data/models/user.dart';
import '../bookings/bloc/my_bookings_bloc.dart';
import '../bookings/presentation/my_bookings_screen.dart';
import '../driver/bloc/my_rides_cubit.dart';
import '../driver/presentation/drive_screen.dart';
import '../places/bloc/places_cubit.dart';
import '../profile/presentation/profile_screen.dart';
import '../rides/presentation/search_screen.dart';
import '../trust/bloc/verifications_cubit.dart';
import '../vehicles/bloc/vehicles_cubit.dart';
import 'dashboard_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  bool get _isDriver => widget.user.isDriver;

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
    // Tab layout: Home · Search · [Drive] · Bookings · Profile
    const homeIndex = 0;
    const searchIndex = 1;
    final driveIndex = _isDriver ? 2 : -1;
    final bookingsIndex = _isDriver ? 3 : 2;
    final profileIndex = _isDriver ? 4 : 3;
    if (_tab > profileIndex) _tab = 0;

    final title = _tab == searchIndex
        ? 'Find a ride'
        : _tab == driveIndex
            ? 'My rides'
            : _tab == bookingsIndex
                ? 'My bookings'
                : 'Profile';

    final body = _tab == homeIndex
        ? DashboardScreen(
            user: widget.user,
            onOpenSearch: ({bool ladiesOnly = false}) =>
                setState(() => _tab = searchIndex),
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
            ? const SearchScreen()
            : _tab == driveIndex
                ? const DriveScreen()
                : _tab == bookingsIndex
                    ? const MyBookingsScreen()
                    : ProfileScreen(user: widget.user);

    return Scaffold(
      appBar: _tab == homeIndex
          ? null
          : AppBar(title: Text(title), centerTitle: false),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == driveIndex) context.read<MyRidesCubit>().load();
          if (i == bookingsIndex) {
            context.read<MyBookingsBloc>().add(const MyBookingsRequested());
          }
          if (i == profileIndex) {
            context.read<VehiclesCubit>().load();
            context.read<VerificationsCubit>().load();
          }
        },
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          const NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          if (_isDriver)
            const NavigationDestination(
                icon: Icon(Icons.directions_car_outlined), label: 'Drive'),
          const NavigationDestination(
              icon: Icon(Icons.confirmation_number_outlined), label: 'Bookings'),
          const NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
