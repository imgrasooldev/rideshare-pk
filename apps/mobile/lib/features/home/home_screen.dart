import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../auth/data/models/user.dart';
import '../bookings/bloc/my_bookings_bloc.dart';
import '../bookings/presentation/my_bookings_screen.dart';
import '../profile/presentation/profile_screen.dart';
import '../rides/presentation/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user});

  final User user;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_tab) {
          0 => 'Find a ride',
          1 => 'My bookings',
          _ => 'Profile',
        }),
        centerTitle: false,
      ),
      body: switch (_tab) {
        0 => const SearchScreen(),
        1 => const MyBookingsScreen(),
        _ => ProfileScreen(user: widget.user),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 1) {
            context.read<MyBookingsBloc>().add(const MyBookingsRequested());
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
          NavigationDestination(icon: Icon(Icons.confirmation_number_outlined), label: 'Bookings'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
