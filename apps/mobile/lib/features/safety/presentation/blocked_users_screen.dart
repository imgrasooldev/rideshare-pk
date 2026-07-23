import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/widgets/empty_state.dart';
import '../bloc/blocks_cubit.dart';
import '../data/blocks_repository.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => BlocksCubit(ctx.read<BlocksRepository>())..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Blocked people')),
        body: BlocBuilder<BlocksCubit, BlocksState>(
          builder: (context, state) => switch (state) {
            BlocksLoading() => const Center(child: CircularProgressIndicator()),
            BlocksError(:final message) => EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load your list',
                message: message,
                isError: true,
                action: TextButton(
                  onPressed: () => context.read<BlocksCubit>().load(),
                  child: const Text('Retry'),
                ),
              ),
            BlocksLoaded(:final people) when people.isEmpty => const EmptyState(
                icon: Icons.shield_outlined,
                title: 'No one is blocked',
                message:
                    "If someone makes you uncomfortable, block them — you'll never be matched "
                    'with each other again.',
              ),
            BlocksLoaded(:final people, :final busyIds) => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: people.length + 1,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  if (i == people.length) return const _BlockExplainer();
                  final person = people[i];
                  return _BlockedTile(
                    person: person,
                    busy: busyIds.contains(person.userId),
                  );
                },
              ),
          },
        ),
      ),
    );
  }
}

class _BlockedTile extends StatelessWidget {
  const _BlockedTile({required this.person, required this.busy});

  final BlockedUser person;
  final bool busy;

  Future<void> _confirmUnblock(BuildContext context) async {
    final cubit = context.read<BlocksCubit>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Unblock ${person.label}?'),
        content: const Text(
          'You may be matched with each other again, and they will be able to '
          'see and book your rides.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Unblock')),
        ],
      ),
    );
    if (ok == true) await cubit.unblock(person.userId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.errorContainer,
          child: Icon(Icons.person_off_outlined, color: theme.colorScheme.onErrorContainer),
        ),
        title: Text(person.label, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(
          [
            if (person.reason?.isNotEmpty == true) person.reason!,
            'Blocked ${DateFormat('d MMM yyyy').format(person.createdAt)}',
          ].join(' · '),
        ),
        trailing: TextButton(
          onPressed: busy ? null : () => _confirmUnblock(context),
          child: Text(busy ? '…' : 'Unblock'),
        ),
      ),
    );
  }
}

class _BlockExplainer extends StatelessWidget {
  const _BlockExplainer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Blocking works both ways: their rides are hidden from you, yours are hidden '
        'from them, and neither of you can book the other.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
        textAlign: TextAlign.center,
      ),
    );
  }
}
