import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/home_screen.dart';

class RideshareApp extends StatelessWidget {
  const RideshareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rideshare PK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF01411C)), // Pakistan green
        useMaterial3: true,
      ),
      home: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) => switch (state) {
          AuthAuthenticated(:final user) => HomeScreen(user: user),
          AuthRestoring() =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
          _ => const LoginScreen(),
        },
      ),
    );
  }
}
