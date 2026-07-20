import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/data/models/user.dart';
import '../bookings/bloc/my_bookings_bloc.dart';
import '../bookings/presentation/my_bookings_screen.dart';
import '../driver/bloc/my_rides_cubit.dart';
import '../driver/presentation/drive_screen.dart';
import '../profile/presentation/profile_screen.dart';
import '../rides/presentation/search_screen.dart';
import '../trust/bloc/verifications_cubit.dart';
import '../vehicles/bloc/vehicles_cubit.dart';

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
  Widget build(BuildContext context) {
    // Tab layout: Search · [Drive] · Bookings · Profile
    final driveIndex = _isDriver ? 1 : -1;
    final bookingsIndex = _isDriver ? 2 : 1;
    final profileIndex = _isDriver ? 3 : 2;
    if (_tab > profileIndex) _tab = 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0
            ? 'Find a ride'
            : _tab == driveIndex
                ? 'My rides'
                : _tab == bookingsIndex
                    ? 'My bookings'
                    : 'Profile'),
        centerTitle: false,
      ),
      body: _tab == 0
          ? const SearchScreen()
          : _tab == driveIndex
              ? const DriveScreen()
              : _tab == bookingsIndex
                  ? const MyBookingsScreen()
                  : ProfileScreen(user: widget.user),
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
