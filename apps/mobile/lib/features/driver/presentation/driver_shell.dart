import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../l10n/app_localizations.dart';
import '../../app_mode/app_mode_cubit.dart';
import '../../auth/data/models/user.dart';
import '../../earnings/bloc/earnings_cubit.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../trust/bloc/verifications_cubit.dart';
import '../../vehicles/bloc/vehicles_cubit.dart';
import '../bloc/my_rides_cubit.dart';
import 'drive_screen.dart';
import 'driver_home_screen.dart';

/// Driver Mode shell — an earning-focused product distinct from passenger mode.
/// Tabs: Dashboard · Rides · Profile. No booking or passenger-search UI.
class DriverShell extends StatefulWidget {
  const DriverShell({super.key, required this.user});
  final User user;

  @override
  State<DriverShell> createState() => _DriverShellState();
}

class _DriverShellState extends State<DriverShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Populate the dashboard: earnings + the driver's posted rides, and sync
    // the online toggle to the driver's stored availability.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MyRidesCubit>().load();
      context.read<EarningsCubit>().load();
      context.read<AppModeCubit>().setOnline(widget.user.isOnline);
    });
  }

  @override
  Widget build(BuildContext context) {
    const dashboardIndex = 0;
    const ridesIndex = 1;
    const profileIndex = 2;

    final title = _tab == ridesIndex ? 'My rides' : 'Profile';

    final body = _tab == dashboardIndex
        ? DriverHomeScreen(
            user: widget.user,
            onOpenRides: () => setState(() => _tab = ridesIndex),
            onOpenProfile: () {
              setState(() => _tab = profileIndex);
              context.read<VehiclesCubit>().load();
              context.read<VerificationsCubit>().load();
            },
          )
        : _tab == ridesIndex
            ? const DriveScreen()
            : ProfileScreen(user: widget.user);

    return Scaffold(
      appBar: _tab == dashboardIndex
          ? null
          : AppBar(title: Text(title), centerTitle: false),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == ridesIndex) {
            context.read<MyRidesCubit>().load();
            context.read<EarningsCubit>().load();
          }
          if (i == profileIndex) {
            context.read<VehiclesCubit>().load();
            context.read<VerificationsCubit>().load();
          }
        },
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard_rounded),
              label: L.of(context).navDashboard),
          NavigationDestination(
              icon: const Icon(Icons.directions_car_outlined), label: L.of(context).navRides),
          NavigationDestination(
              icon: const Icon(Icons.person_outline), label: L.of(context).navProfile),
        ],
      ),
    );
  }
}
