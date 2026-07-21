import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/bloc/auth_bloc.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/splash_screen.dart';

class RideshareApp extends StatelessWidget {
  const RideshareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rideshare PK',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const _RootGate(),
    );
  }
}

/// Splash → first-launch onboarding (once) → authenticated app. Onboarding
/// state is persisted so returning users skip straight to login/home.
class _RootGate extends StatefulWidget {
  const _RootGate();

  @override
  State<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<_RootGate> {
  static const _kOnboardingSeen = 'onboarding_completed';

  bool _splashDone = false;
  bool _onboardingSeen = true;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool(_kOnboardingSeen) ?? false;
    // Hold the splash briefly so it never just flashes; session restore and
    // prefs read both complete well within this window.
    await Future<void>.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    setState(() {
      _onboardingSeen = seen;
      _splashDone = true;
    });
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingSeen, true);
    if (!mounted) return;
    setState(() => _onboardingSeen = true);
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (!_splashDone) {
      child = const SplashScreen();
    } else if (!_onboardingSeen) {
      child = OnboardingScreen(onDone: _completeOnboarding);
    } else {
      child = const _AuthGate();
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      child: KeyedSubtree(
        key: ValueKey('${_splashDone}_$_onboardingSeen'),
        child: child,
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) => switch (state) {
        AuthAuthenticated(:final user) => HomeScreen(user: user),
        AuthRestoring() =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
        _ => const LoginScreen(),
      },
    );
  }
}
