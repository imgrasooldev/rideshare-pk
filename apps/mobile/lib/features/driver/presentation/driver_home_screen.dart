import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../app_mode/app_mode_cubit.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/models/user.dart';
import '../../bookings/presentation/requests_screen.dart';
import '../../earnings/bloc/earnings_cubit.dart';
import '../../wallet/presentation/wallet_screen.dart';
import '../bloc/my_rides_cubit.dart';
import 'post_ride_screen.dart';

/// Driver Mode home — earning-focused. No booking buttons, no passenger search:
/// online/offline, earnings, quick actions, and today's pickups.
class DriverHomeScreen extends StatelessWidget {
  const DriverHomeScreen({
    super.key,
    required this.user,
    required this.onOpenRides,
    required this.onOpenProfile,
  });

  final User user;
  final VoidCallback onOpenRides;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final name = (user.name?.trim().isNotEmpty ?? false)
        ? user.name!.trim().split(' ').first
        : 'Captain';
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _DriverHeader(name: name),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _EarningsHero(),
                const SizedBox(height: 20),
                Text('Quick actions',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _QuickActions(onOpenRides: onOpenRides, onOpenProfile: onOpenProfile),
                const SizedBox(height: 24),
                Text("Today's pickups",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _TodaysPickups(onOpenRides: onOpenRides),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Red header with an online/offline toggle and a one-tap switch to Passenger.
class _DriverHeader extends StatelessWidget {
  const _DriverHeader({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(top: topInset + 14, left: 16, right: 16, bottom: 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B1B1F), Color(0xFF3A0E10)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE81E2D),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.directions_car_filled_rounded, size: 15, color: Colors.white),
                    SizedBox(width: 6),
                    Text('DRIVER MODE',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4)),
                  ],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => context.read<AppModeCubit>().toPassenger(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: const Text('Passenger',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Assalam-o-Alaikum, $name',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
          const SizedBox(height: 3),
          const Text('Ready to earn?',
              style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          const _OnlineToggle(),
        ],
      ),
    );
  }
}

class _OnlineToggle extends StatelessWidget {
  const _OnlineToggle();

  Future<void> _toggleOnline(BuildContext context, bool value) async {
    final appMode = context.read<AppModeCubit>();
    final auth = context.read<AuthRepository>();
    final authBloc = context.read<AuthBloc>();
    final messenger = ScaffoldMessenger.of(context);
    appMode.setOnline(value); // optimistic
    try {
      final user = await auth.setOnline(value);
      authBloc.add(AuthProfileRefreshed(user));
    } catch (_) {
      appMode.setOnline(!value); // revert
      messenger.showSnackBar(const SnackBar(content: Text('Could not update status')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AppModeCubit, AppModeState>(
      builder: (context, state) {
        final online = state.online;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: online ? const Color(0xFF12A46B) : const Color(0xFFB0B0B8),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(online ? "You're online" : "You're offline",
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(
                        online
                            ? 'Receiving booking requests'
                            : 'Go online to receive requests',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Switch(
                value: online,
                onChanged: (v) => _toggleOnline(context, v),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact earnings summary card, reads the shared EarningsCubit.
class _EarningsHero extends StatelessWidget {
  const _EarningsHero();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return BlocBuilder<EarningsCubit, EarningsState>(
      builder: (context, state) {
        final e = state is EarningsLoaded ? state.data : null;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF5A47), Color(0xFFE81E2D)],
            ),
            boxShadow: [
              BoxShadow(
                  color: primary.withValues(alpha: 0.3),
                  blurRadius: 22,
                  offset: const Offset(0, 12)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Today's earnings",
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(e == null ? 'Rs —' : 'Rs ${e.today}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5)),
              const SizedBox(height: 14),
              Row(
                children: [
                  _HeroStat(label: 'This month', value: e == null ? '—' : 'Rs ${e.thisMonth}'),
                  _HeroDivider(),
                  _HeroStat(label: 'Net', value: e == null ? '—' : 'Rs ${e.netThisMonth}'),
                  _HeroDivider(),
                  _HeroStat(label: 'Trips', value: e == null ? '—' : '${e.tripsThisMonth}'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
        ],
      ),
    );
  }
}

class _HeroDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: 30,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white.withValues(alpha: 0.25),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onOpenRides, required this.onOpenProfile});
  final VoidCallback onOpenRides;
  final VoidCallback onOpenProfile;

  void _soon(BuildContext context, String name) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$name is coming soon')));
  }

  void _openWallet(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const WalletScreen()));
  }

  void _openRequests(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const RequestsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final actions = <_Action>[
      _Action('Post a ride', Icons.add_road_rounded, const Color(0xFFE81E2D),
          const Color(0xFFFFECEB), () async {
        final posted = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const PostRideScreen()),
        );
        if (posted == true && context.mounted) {
          context.read<MyRidesCubit>().load();
          context.read<EarningsCubit>().load();
        }
      }),
      _Action('Requests', Icons.inbox_rounded, const Color(0xFF1E88D6),
          const Color(0xFFE1F1FD), () => _openRequests(context)),
      _Action('My rides', Icons.route_rounded, const Color(0xFF7C5AE0),
          const Color(0xFFEDE9FD), onOpenRides),
      _Action('Vehicles', Icons.directions_car_rounded, const Color(0xFF12A46B),
          const Color(0xFFDFF6EC), onOpenProfile),
      _Action('Wallet', Icons.account_balance_wallet_rounded, const Color(0xFFE19700),
          const Color(0xFFFFF3D6), () => _openWallet(context)),
      _Action('Support', Icons.headset_mic_rounded, const Color(0xFF0FA898),
          const Color(0xFFD9F5F0), () => _soon(context, 'Support')),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 11,
      crossAxisSpacing: 11,
      childAspectRatio: 0.92,
      children: [for (final a in actions) _ActionTile(action: a)],
    );
  }
}

class _Action {
  const _Action(this.label, this.icon, this.color, this.tint, this.onTap);
  final String label;
  final IconData icon;
  final Color color;
  final Color tint;
  final VoidCallback onTap;
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.action});
  final _Action action;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: const Color(0x14101828),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: action.onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(color: action.tint, borderRadius: BorderRadius.circular(12)),
                child: Icon(action.icon, color: action.color, size: 21),
              ),
              const SizedBox(height: 8),
              Text(action.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Upcoming open rides from the driver's own posted rides.
class _TodaysPickups extends StatelessWidget {
  const _TodaysPickups({required this.onOpenRides});
  final VoidCallback onOpenRides;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<MyRidesCubit, MyRidesState>(
      builder: (context, state) {
        if (state is! MyRidesLoaded) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final upcoming = state.rides
            .where((r) => r.status == 'open' || r.status == 'full')
            .toList()
          ..sort((a, b) => a.departAt.compareTo(b.departAt));
        if (upcoming.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Icon(Icons.event_available_rounded,
                    size: 34, color: theme.colorScheme.outline),
                const SizedBox(height: 8),
                Text('No pickups scheduled',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text('Post a ride to start filling seats.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final r in upcoming.take(3))
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onOpenRides,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.schedule_rounded,
                                color: theme.colorScheme.primary, size: 21),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${r.originLabel} → ${r.destLabel}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                    '${DateFormat('EEE, d MMM • h:mm a').format(r.departAt)}'
                                    '  ·  ${r.seatsAvailable}/${r.seatsTotal} seats',
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: theme.colorScheme.outline)),
                              ],
                            ),
                          ),
                          Text('Rs ${r.pricePerSeat}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
