import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../bloc/subscriptions_cubit.dart';
import '../data/subscriptions_repository.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SubscriptionsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My subscriptions')),
      body: BlocBuilder<SubscriptionsCubit, SubscriptionsState>(
        builder: (context, state) => switch (state) {
          SubscriptionsLoading() => const Center(child: CircularProgressIndicator()),
          SubscriptionsError(:final message) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(message, textAlign: TextAlign.center),
              ),
            ),
          SubscriptionsLoaded(:final items) when items.isEmpty => _Empty(theme: theme),
          SubscriptionsLoaded(:final items, :final busyId) => RefreshIndicator(
              onRefresh: () => context.read<SubscriptionsCubit>().load(),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _Card(sub: items[i], busy: busyId == items[i].id),
              ),
            ),
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
                color: theme.colorScheme.primary.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(Icons.event_repeat_rounded, size: 32, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 14),
          Text('No monthly routes yet',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text('Subscribe to a daily route from Search and skip booking every morning.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.sub, required this.busy});
  final Subscription sub;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = sub.isActive;
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFDFF6EC)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999)),
                child: Text(active ? 'ACTIVE' : sub.status.toUpperCase(),
                    style: TextStyle(
                        color: active ? const Color(0xFF12A46B) : theme.colorScheme.outline,
                        fontSize: 10,
                        fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              Text('Rs ${sub.pricePerMonth}',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
              Text('/mo',
                  style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: [
                _dot(const Color(0xFF12A46B)),
                Container(width: 2, height: 20, color: theme.colorScheme.outlineVariant),
                _dot(theme.colorScheme.primary),
              ]),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sub.originLabel ?? 'Pickup',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(sub.destLabel ?? 'Drop-off',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.event_repeat_rounded, size: 15, color: theme.colorScheme.outline),
              const SizedBox(width: 6),
              Text(
                  active
                      ? 'Renews ${DateFormat('d MMM').format(sub.renewsOn)} · ${sub.seats} seat${sub.seats > 1 ? 's' : ''}'
                      : 'Ended',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              const Spacer(),
              if (active)
                busy
                    ? const SizedBox.square(
                        dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(
                        onPressed: () => context.read<SubscriptionsCubit>().cancel(sub.id),
                        style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.error,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32)),
                        child: const Text('Cancel'),
                      ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c) =>
      Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle));
}
