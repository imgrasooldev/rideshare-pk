import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/widgets/empty_state.dart';
import '../data/credits_repository.dart';

/// Rider wallet. Balance is a running total of ledger entries; the only live
/// credit source today is referral rewards. Online top-up is stubbed until a
/// payment gateway is wired, so we tell the user rather than pretend.
class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  late Future<CreditSummary> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = context.read<CreditsRepository>().summary();
  }

  void _reload() => setState(() => _future = context.read<CreditsRepository>().summary());

  Future<void> _redeem() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final credited = await context.read<CreditsRepository>().redeemReferrals();
      messenger.showSnackBar(SnackBar(
        content: Text(credited > 0
            ? 'Added $credited referral reward${credited > 1 ? 's' : ''} to your wallet'
            : 'No new referral rewards to redeem'),
      ));
      _reload();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not redeem right now')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _topupInfo() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add credit'),
        content: const Text(
            'Online top-up (JazzCash, Easypaisa, Raast, card) is coming soon. '
            'For now, earn credit by referring friends.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: FutureBuilder<CreditSummary>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || !snap.hasData) {
            return EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Could not load your wallet',
              message: 'Check your connection and try again.',
              isError: true,
              action: TextButton(onPressed: _reload, child: const Text('Retry')),
            );
          }
          final data = snap.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _BalanceCard(rupees: data.balanceRupees),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _busy ? null : _redeem,
                        icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                        label: Text(_busy ? '…' : 'Redeem referral rewards'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _topupInfo,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Activity',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                if (data.entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('No activity yet. Refer a friend to earn credit.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.outline)),
                  )
                else
                  for (final e in data.entries) _EntryTile(entry: e),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.rupees});
  final double rupees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Wallet balance',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.85))),
          const SizedBox(height: 6),
          Text('Rs ${rupees.toStringAsFixed(0)}',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final CreditEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final credit = entry.amountPaisa >= 0;
    final label = entry.description ??
        entry.kind.replaceAll('_', ' ').replaceFirstMapped(
            RegExp(r'^\w'), (m) => m.group(0)!.toUpperCase());
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: (credit ? Colors.green : theme.colorScheme.error)
            .withValues(alpha: 0.12),
        child: Icon(credit ? Icons.south_west_rounded : Icons.north_east_rounded,
            color: credit ? Colors.green.shade700 : theme.colorScheme.error, size: 18),
      ),
      title: Text(label),
      subtitle: Text(DateFormat('d MMM y').format(entry.createdAt)),
      trailing: Text(
        '${credit ? '+' : '−'}Rs ${entry.amountRupees.abs().toStringAsFixed(0)}',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: credit ? Colors.green.shade700 : theme.colorScheme.error,
        ),
      ),
    );
  }
}
