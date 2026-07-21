import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../auth/data/models/user.dart';
import '../bookings/bloc/my_bookings_bloc.dart';
import '../categories/bloc/categories_cubit.dart';
import '../categories/data/categories_repository.dart';
import '../driver/presentation/become_driver_screen.dart';
import '../messages/bloc/messages_unread_cubit.dart';
import '../messages/presentation/inbox_screen.dart';
import '../notifications/bloc/notifications_cubit.dart';
import '../notifications/presentation/notifications_screen.dart';
import '../places/bloc/places_cubit.dart';
import '../rides/bloc/ride_search_bloc.dart';
import '../rides/data/models/ride.dart';

/// Soft floating shadow used across dashboard cards for depth.
const _softShadow = [
  BoxShadow(color: Color(0x14101828), blurRadius: 18, offset: Offset(0, 8)),
];

/// The Yango-style super-app home: greeting, search entry, service grid, and a
/// live "near you" strip driven by the shared RideSearchBloc.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    super.key,
    required this.user,
    required this.onOpenSearch,
    required this.onOpenBookings,
    required this.onOpenProfile,
  });

  final User user;

  /// Opens the Search tab; [ladiesOnly] pre-selects the ladies filter and
  /// [vertical] pre-selects a category filter.
  final void Function({bool ladiesOnly, String? vertical}) onOpenSearch;

  /// Switch to the Bookings tab.
  final VoidCallback onOpenBookings;

  /// Switch to the Profile tab (for verification).
  final VoidCallback onOpenProfile;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load the user's bookings so the home can surface their next ride.
      context.read<MyBookingsBloc>().add(const MyBookingsRequested());
      // Load the notification bell's unread count.
      context.read<NotificationsCubit>().load();
      // Load the chat unread badge.
      context.read<MessagesUnreadCubit>().load();
    });
  }

  void _comingSoon(String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$name is coming soon')),
    );
  }

  /// Refresh "Live near you" for the loaded city, using its first two hubs as a
  /// sample corridor. Fires whenever the selected city's hubs change.
  void _refreshLive(PlacesState places) {
    if (places.hubs.length < 2) return;
    context.read<RideSearchBloc>().add(RideSearchSubmitted(
          pickup: places.hubs[0],
          drop: places.hubs[1],
          day: DateTime.now().add(const Duration(days: 1)),
          ladiesOnly: false,
          vehicleType: null,
        ));
  }

  void _openCityPicker() {
    final cubit = context.read<PlacesCubit>();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Select your city',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            for (final c in cubit.state.cities)
              ListTile(
                leading: const Icon(Icons.location_city_rounded),
                title: Text(c.name),
                trailing: cubit.state.city == c.slug
                    ? Icon(Icons.check_circle_rounded,
                        color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () {
                  cubit.load(c.slug);
                  Navigator.of(context).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.user.name?.trim().isNotEmpty ?? false)
        ? widget.user.name!.trim().split(' ').first
        : 'there';

    return BlocListener<PlacesCubit, PlacesState>(
      listenWhen: (p, c) => p.hubs != c.hubs,
      listener: (context, state) => _refreshLive(state),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(
              user: widget.user,
              name: name,
              onOpenSearch: () => widget.onOpenSearch(),
              onTapLocation: _openCityPicker,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 36, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroCard(onTap: () => widget.onOpenSearch()),
                const SizedBox(height: 14),
                if (!widget.user.verified) _VerifyBanner(onTap: widget.onOpenProfile),
                _NextRideCard(onTap: widget.onOpenBookings),
                const _StatsStrip(),
                if (!widget.user.isDriver) ...[
                  const SizedBox(height: 12),
                  _OfferCarCard(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const BecomeDriverScreen()),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Text('All services',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                _ServiceGrid(
                  onOpenSearch: widget.onOpenSearch,
                  onComingSoon: _comingSoon,
                ),
                const SizedBox(height: 24),
                const _LiveNearYouHeader(),
                const SizedBox(height: 12),
                _LiveNearYou(onTapRide: () => widget.onOpenSearch()),
              ],
            ),
          ),
          ],
        ),
      ),
    );
  }
}

/// Branded red header: location, notifications, avatar, greeting, and a search
/// bar that floats over the boundary onto the content below.
class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.name,
    required this.onOpenSearch,
    required this.onTapLocation,
  });
  final User user;
  final String name;
  final VoidCallback onOpenSearch;
  final VoidCallback onTapLocation;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final selected = context.watch<PlacesCubit>().state.city;
    final rawCity = (selected ?? '').isNotEmpty
        ? selected!
        : (user.city.trim().isNotEmpty ? user.city : 'lahore');
    final city = '${rawCity[0].toUpperCase()}${rawCity.substring(1)}';
    final initial = (name.isNotEmpty ? name[0] : 'U').toUpperCase();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.only(top: topInset + 14, left: 16, right: 16, bottom: 42),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF5A47), Color(0xFFE81E2D)],
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: onTapLocation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(city,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const Icon(Icons.expand_more_rounded, size: 16, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const _ChatButton(),
                  const SizedBox(width: 10),
                  const _NotifBell(),
                  const SizedBox(width: 10),
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Text(initial,
                        style: const TextStyle(
                            color: Color(0xFFE81E2D), fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Assalam-o-Alaikum, $name',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
              const SizedBox(height: 3),
              const Text('Where to today?',
                  style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: -26,
          child: _SearchBar(onTap: onOpenSearch),
        ),
      ],
    );
  }

}

/// Header chat button — opens the conversations inbox with an unread badge.
class _ChatButton extends StatelessWidget {
  const _ChatButton();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const InboxScreen()),
        );
        if (context.mounted) context.read<MessagesUnreadCubit>().load();
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded, size: 19, color: Colors.white),
          ),
          BlocBuilder<MessagesUnreadCubit, int>(
            builder: (context, unread) {
              if (unread == 0) return const SizedBox.shrink();
              return Positioned(
                top: -3,
                right: -3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE81E2D), width: 1.5),
                  ),
                  child: Text(
                    unread > 9 ? '9+' : '$unread',
                    style: const TextStyle(
                        color: Color(0xFFE81E2D),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Header bell — opens the notification center and shows the unread count.
class _NotifBell extends StatelessWidget {
  const _NotifBell();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const NotificationsScreen()),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded, size: 20, color: Colors.white),
          ),
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              if (state.unread == 0) return const SizedBox.shrink();
              return Positioned(
                top: -3,
                right: -3,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE81E2D), width: 1.5),
                  ),
                  child: Text(
                    state.unread > 9 ? '9+' : '${state.unread}',
                    style: const TextStyle(
                        color: Color(0xFFE81E2D),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Service {
  const _Service(this.name, this.icon, this.color, this.tint, this.onTap,
      {this.soon = false});
  final String name;
  final IconData icon;
  final Color color;
  final Color tint;
  final VoidCallback onTap;
  final bool soon;
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(15),
      elevation: 3,
      shadowColor: const Color(0x14101828),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: theme.colorScheme.outline),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Search destination or route',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
              ),
              Icon(Icons.mic_none_rounded, size: 20, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: _softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFF5A47), Color(0xFFE81E2D)],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color: primary.withValues(alpha: 0.3),
                          blurRadius: 14,
                          offset: const Offset(0, 6)),
                    ],
                  ),
                  child: const Icon(Icons.work_outline_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFECEB),
                            borderRadius: BorderRadius.circular(999)),
                        child: Text('SAVE UP TO 60%',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: primary, fontWeight: FontWeight.w800, fontSize: 10)),
                      ),
                      const SizedBox(height: 7),
                      const Text('Office Pick & Drop',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Daily commute — verified riders',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 20, color: primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Real quick-stats: the user's booking count, live rides near them, and the
/// cash-only marketplace fact.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BlocBuilder<MyBookingsBloc, MyBookingsState>(
            builder: (context, state) => _TrustCell(
              value: state is MyBookingsLoaded ? '${state.bookings.length}' : '—',
              label: 'Your trips',
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: BlocBuilder<RideSearchBloc, RideSearchState>(
            builder: (context, state) => _TrustCell(
              value: state is RideSearchLoaded ? '${state.rides.length}' : '—',
              label: 'Near you',
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: _TrustCell(value: 'Cash', label: 'No wallet')),
      ],
    );
  }
}

/// Rider → provider entry: offer your own car for carpooling.
class _OfferCarCard extends StatelessWidget {
  const _OfferCarCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: primary.withValues(alpha: 0.25)),
            gradient: LinearGradient(
              colors: [primary.withValues(alpha: 0.07), primary.withValues(alpha: 0.02)],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.directions_car_filled_rounded, color: primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Offer your car',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('Earn by sharing your daily commute',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: primary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nudge for unverified users — a real, actionable prompt to the profile tab.
class _VerifyBanner extends StatelessWidget {
  const _VerifyBanner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3D9A6)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration:
                      const BoxDecoration(color: Color(0xFFFCEBC6), shape: BoxShape.circle),
                  child: const Icon(Icons.verified_user_outlined,
                      color: Color(0xFFB77400), size: 21),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Get verified',
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF8A5A00))),
                      SizedBox(height: 2),
                      Text('Unlock your trust badge and post rides',
                          style: TextStyle(fontSize: 12, color: Color(0xFFA9803A))),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 18, color: Color(0xFFB77400)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The user's soonest active booking, surfaced from /bookings/mine.
class _NextRideCard extends StatelessWidget {
  const _NextRideCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<MyBookingsBloc, MyBookingsState>(
      builder: (context, state) {
        if (state is! MyBookingsLoaded) return const SizedBox.shrink();
        final active = state.bookings.where((b) => b.isActive).toList()
          ..sort((a, b) =>
              (a.departAt ?? a.createdAt).compareTo(b.departAt ?? b.createdAt));
        if (active.isEmpty) return const SizedBox.shrink();
        final b = active.first;
        final when = b.departAt != null
            ? DateFormat('EEE, d MMM • h:mm a').format(b.departAt!)
            : 'Time to be confirmed';
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            boxShadow: _softShadow,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('YOUR UPCOMING RIDE',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3)),
                        const Spacer(),
                        _StatusPill(status: b.status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(children: [
                          const _Dot(Color(0xFF12A46B)),
                          Container(width: 2, height: 22, color: theme.colorScheme.outlineVariant),
                          _Dot(theme.colorScheme.primary),
                        ]),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.originLabel ?? 'Pickup',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              Text(b.destLabel ?? 'Drop-off',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        if (b.pricePerSeat != null) ...[
                          const SizedBox(width: 8),
                          Text('Rs ${b.pricePerSeat! * b.seats}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 15, color: theme.colorScheme.outline),
                        const SizedBox(width: 6),
                        Text(when,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline)),
                        const Spacer(),
                        Text('${b.seats} seat${b.seats > 1 ? 's' : ''}',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final confirmed = status == 'confirmed';
    final color = confirmed ? const Color(0xFF12A46B) : const Color(0xFFB77400);
    final tint = confirmed ? const Color(0xFFDFF6EC) : const Color(0xFFFCEBC6);
    final label = status.isEmpty ? '' : status[0].toUpperCase() + status.substring(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _TrustCell extends StatelessWidget {
  const _TrustCell({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: _softShadow,
      ),
      child: Column(
        children: [
          Text(value,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 1),
          Text(label,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

/// Symbolic icon names (from the /categories catalog) → Flutter icons.
IconData _categoryIcon(String name) => switch (name) {
      'briefcase' => Icons.work_outline_rounded,
      'road' => Icons.alt_route_rounded,
      'school' => Icons.school_outlined,
      'female' => Icons.favorite_outline_rounded,
      'flight' => Icons.flight_rounded,
      'business' => Icons.business_rounded,
      'celebration' => Icons.celebration_outlined,
      'car_rental' => Icons.car_rental_rounded,
      'package' => Icons.local_shipping_outlined,
      _ => Icons.directions_car_rounded,
    };

/// Brand accent + tint per category key, matching the Yango palette.
(Color, Color) _categoryColors(String key) => switch (key) {
      'office' => (const Color(0xFFFF3B30), const Color(0xFFFFECEB)),
      'city' => (const Color(0xFF1E88D6), const Color(0xFFE1F1FD)),
      'school' => (const Color(0xFFE19700), const Color(0xFFFFF3D6)),
      'ladies' => (const Color(0xFFD6488B), const Color(0xFFFCE7F0)),
      'airport' => (const Color(0xFF3B72E0), const Color(0xFFE4EEFE)),
      'corporate' => (const Color(0xFF7C5AE0), const Color(0xFFEDE9FD)),
      'events' => (const Color(0xFF0FA898), const Color(0xFFD9F5F0)),
      'rentacar' => (const Color(0xFF12A46B), const Color(0xFFDFF6EC)),
      'parcel' => (const Color(0xFFE24657), const Color(0xFFFDE7EA)),
      _ => (const Color(0xFFFF3B30), const Color(0xFFFFECEB)),
    };

/// Static mirror of the backend catalog — the grid always renders, even before
/// (or without) a network round-trip.
const _fallbackCategories = <Category>[
  Category(key: 'office', label: 'Office Commute', tagline: 'Daily ride to work', icon: 'briefcase', active: true, comingSoon: false, sort: 1),
  Category(key: 'city', label: 'Intercity', tagline: 'Between cities', icon: 'road', active: true, comingSoon: false, sort: 2),
  Category(key: 'school', label: 'School Van', tagline: 'Safe school pickup', icon: 'school', active: true, comingSoon: false, sort: 3),
  Category(key: 'ladies', label: 'Ladies Only', tagline: 'Women-only rides', icon: 'female', active: true, comingSoon: false, sort: 4),
  Category(key: 'airport', label: 'Airport', tagline: 'To & from the airport', icon: 'flight', active: true, comingSoon: false, sort: 5),
  Category(key: 'corporate', label: 'Corporate', tagline: 'Company fleets', icon: 'business', active: true, comingSoon: false, sort: 6),
  Category(key: 'events', label: 'Events', tagline: 'Weddings & occasions', icon: 'celebration', active: true, comingSoon: false, sort: 7),
  Category(key: 'rentacar', label: 'Rent a Car', tagline: 'With or without driver', icon: 'car_rental', active: false, comingSoon: true, sort: 8),
  Category(key: 'parcel', label: 'Parcel', tagline: 'Send packages', icon: 'package', active: false, comingSoon: true, sort: 9),
];

/// The service grid — dynamic from /categories, falling back to the static
/// catalog while loading or offline.
class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.onOpenSearch, required this.onComingSoon});
  final void Function({bool ladiesOnly, String? vertical}) onOpenSearch;
  final void Function(String label) onComingSoon;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CategoriesCubit, CategoriesState>(
      builder: (context, state) {
        final items = state is CategoriesLoaded && state.items.isNotEmpty
            ? state.items
            : _fallbackCategories;
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 11,
          crossAxisSpacing: 11,
          childAspectRatio: 1.55,
          children: [
            for (final c in items)
              _ServiceTile(
                service: _serviceFrom(c),
              ),
          ],
        );
      },
    );
  }

  _Service _serviceFrom(Category c) {
    final (color, tint) = _categoryColors(c.key);
    final available = c.active && !c.comingSoon;
    return _Service(
      c.label,
      _categoryIcon(c.icon),
      color,
      tint,
      available
          ? () => onOpenSearch(vertical: c.key, ladiesOnly: c.key == 'ladies')
          : () => onComingSoon(c.label),
      soon: c.comingSoon,
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service});
  final _Service service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      shadowColor: const Color(0x14101828),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: service.onTap,
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Stack(
            children: [
              if (service.soon)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFCE7F0),
                        borderRadius: BorderRadius.circular(999)),
                    child: const Text('SOON',
                        style: TextStyle(
                            color: Color(0xFFD6488B),
                            fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: service.tint, borderRadius: BorderRadius.circular(13)),
                    child: Icon(service.icon, color: service.color, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(service.name,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveNearYouHeader extends StatelessWidget {
  const _LiveNearYouHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Live near you',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        BlocBuilder<RideSearchBloc, RideSearchState>(
          builder: (context, state) {
            final count = state is RideSearchLoaded ? state.rides.length : 0;
            if (count == 0) return const SizedBox.shrink();
            return Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: Color(0xFF12A46B), shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text('$count active',
                    style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF12A46B), fontWeight: FontWeight.w700)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LiveNearYou extends StatelessWidget {
  const _LiveNearYou({required this.onTapRide});
  final VoidCallback onTapRide;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RideSearchBloc, RideSearchState>(
      builder: (context, state) => switch (state) {
        RideSearchLoading() || RideSearchInitial() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          ),
        RideSearchLoaded(:final rides) when rides.isNotEmpty => Column(
            children: [
              for (final ride in rides.take(3)) _LiveRideCard(ride: ride, onTap: onTapRide),
            ],
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}

class _LiveRideCard extends StatelessWidget {
  const _LiveRideCard({required this.ride, required this.onTap});
  final Ride ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: _softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const _Dot(Color(0xFF12A46B)),
                        Container(width: 2, height: 26, color: theme.colorScheme.outlineVariant),
                        _Dot(theme.colorScheme.primary),
                      ],
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ride.originLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 14),
                          Text(ride.destLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Rs ${ride.pricePerSeat}',
                            style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
                        Text('per seat',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (ride.driverRatingCount > 0) ...[
                      _Pill(
                          icon: Icons.star_rounded,
                          text: ride.driverRatingAvg.toStringAsFixed(1),
                          color: const Color(0xFFE19700),
                          tint: const Color(0xFFFFF3D6)),
                      const SizedBox(width: 8),
                    ],
                    _Pill(icon: Icons.schedule_rounded, text: DateFormat('h:mm a').format(ride.departAt)),
                    const SizedBox(width: 8),
                    _Pill(
                        icon: Icons.airline_seat_recline_normal_rounded,
                        text: '${ride.seatsAvailable} seats'),
                    const SizedBox(width: 8),
                    if (ride.ladiesOnly)
                      const _Pill(
                          icon: Icons.favorite_rounded,
                          text: 'Ladies',
                          color: Color(0xFFD6488B),
                          tint: Color(0xFFFCE7F0)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color);
  final Color color;
  @override
  Widget build(BuildContext context) =>
      Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, this.color, this.tint});
  final IconData icon;
  final String text;
  final Color? color;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = color ?? theme.colorScheme.onSurfaceVariant;
    final bg = tint ?? theme.colorScheme.surfaceContainerHighest;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(text, style: theme.textTheme.labelSmall?.copyWith(color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
