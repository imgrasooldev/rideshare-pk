import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/notifications_cubit.dart';
import '../data/notifications_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<NotificationsCubit>();
    cubit.load();
    // Mark everything read once the user has opened the screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => cubit.markAllRead());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state.loading && !state.loaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.items.isEmpty) {
            return _Empty(theme: theme);
          }
          return RefreshIndicator(
            onRefresh: () => context.read<NotificationsCubit>().load(),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: state.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _Tile(n: state.items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.theme});
  final ThemeData theme;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded,
                size: 32, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 14),
          Text("You're all caught up",
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('New activity on your rides shows up here.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.n});
  final AppNotification n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final v = _visual(n.type);
    return Container(
      decoration: BoxDecoration(
        color: n.read ? theme.cardColor : theme.colorScheme.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: n.read
              ? theme.colorScheme.outlineVariant.withValues(alpha: 0.5)
              : theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: v.tint, borderRadius: BorderRadius.circular(12)),
            child: Icon(v.icon, color: v.color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(n.title,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (!n.read)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 8, top: 5),
                        decoration: BoxDecoration(
                            color: theme.colorScheme.primary, shape: BoxShape.circle),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(n.body,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.outline, height: 1.35)),
                const SizedBox(height: 6),
                Text(_ago(n.createdAt),
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: theme.colorScheme.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Visual {
  const _Visual(this.icon, this.color, this.tint);
  final IconData icon;
  final Color color;
  final Color tint;
}

_Visual _visual(String type) {
  switch (type) {
    case 'booking':
      return const _Visual(Icons.confirmation_number_rounded, Color(0xFFE81E2D), Color(0xFFFFECEB));
    case 'verification':
      return const _Visual(Icons.verified_user_rounded, Color(0xFF12A46B), Color(0xFFDFF6EC));
    case 'ride':
      return const _Visual(Icons.directions_car_rounded, Color(0xFF1E88D6), Color(0xFFE1F1FD));
    case 'safety':
      return const _Visual(Icons.shield_rounded, Color(0xFFB77400), Color(0xFFFCEBC6));
    default:
      return const _Visual(Icons.info_rounded, Color(0xFF7C5AE0), Color(0xFFEDE9FD));
  }
}

String _ago(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24) return '${d.inHours}h ago';
  if (d.inDays < 7) return '${d.inDays}d ago';
  return '${(d.inDays / 7).floor()}w ago';
}
