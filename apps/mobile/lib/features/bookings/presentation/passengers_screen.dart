import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/bookings_repository.dart';
import '../data/models/seat_request.dart';

/// Driver's confirmed passenger manifest for one ride, with a no-show action.
class PassengersScreen extends StatefulWidget {
  const PassengersScreen({super.key, required this.rideId, required this.routeLabel});
  final String rideId;
  final String routeLabel;

  @override
  State<PassengersScreen> createState() => _PassengersScreenState();
}

class _PassengersScreenState extends State<PassengersScreen> {
  late Future<List<SeatRequest>> _future;
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<BookingsRepository>().ridePassengers(widget.rideId);
  }

  Future<void> _noShow(SeatRequest p) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = context.read<BookingsRepository>();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark no-show?'),
        content: Text(
            'Report that ${p.riderName ?? 'this rider'} did not show up. This frees the seat.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Mark no-show')),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy.add(p.id));
    try {
      await repo.noShow(p.id);
      messenger.showSnackBar(const SnackBar(content: Text('Marked as no-show')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not mark no-show')));
    }
    if (mounted) setState(() => _reload());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Passengers'),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(widget.routeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<SeatRequest>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return Center(
              child: Text('No confirmed passengers yet',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final p = list[i];
              final name = (p.riderName?.trim().isNotEmpty ?? false) ? p.riderName!.trim() : 'Rider';
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(name[0].toUpperCase(),
                      style: TextStyle(
                          color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${p.seats} seat${p.seats > 1 ? 's' : ''}'
                    ' · Rs ${(p.effectivePrice ?? 0) * p.seats}'),
                trailing: _busy.contains(p.id)
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(
                        style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                        onPressed: () => _noShow(p),
                        child: const Text('No-show'),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
