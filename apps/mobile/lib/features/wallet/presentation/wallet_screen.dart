import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../bloc/wallet_cubit.dart';
import '../data/wallet_repository.dart';

/// Driver wallet — the platform's commission on cash trips and settling it back.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    context.read<WalletCubit>().load();
  }

  Future<void> _settle(Wallet w) async {
    final controller = TextEditingController(text: '${w.commissionOwed}');
    final messenger = ScaffoldMessenger.of(context);
    final cubit = context.read<WalletCubit>();
    final amount = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Settle commission'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You owe Rs ${w.commissionOwed}. Record a cash deposit to clear it.',
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                prefixText: 'Rs ',
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim()) ?? 0),
            child: const Text('Settle'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0) return;
    final err = await cubit.settle(amount);
    messenger.showSnackBar(SnackBar(
      content: Text(err ?? 'Settled Rs $amount — thank you!'),
      backgroundColor: err == null ? Colors.green.shade700 : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallet'), centerTitle: false),
      body: BlocBuilder<WalletCubit, WalletState>(
        builder: (context, state) => switch (state) {
          WalletLoading() => const Center(child: CircularProgressIndicator()),
          WalletFailed() => _Retry(onRetry: () => context.read<WalletCubit>().load()),
          WalletLoaded(:final wallet, :final history) => RefreshIndicator(
              onRefresh: () => context.read<WalletCubit>().load(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _OwedCard(wallet: wallet, onSettle: () => _settle(wallet)),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                          child: _Stat(
                              label: 'Cash collected', value: 'Rs ${wallet.grossFares}')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _Stat(label: 'You keep', value: 'Rs ${wallet.cashKept}')),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                          child: _Stat(
                              label:
                                  'Commission (${(wallet.commissionRate * 100).round()}%)',
                              value: 'Rs ${wallet.commissionAccrued}')),
                      const SizedBox(width: 10),
                      Expanded(
                          child:
                              _Stat(label: 'Settled', value: 'Rs ${wallet.settledTotal}')),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('Settlement history',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (history.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text('No settlements yet',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Theme.of(context).colorScheme.outline)),
                      ),
                    )
                  else
                    for (final s in history) _SettlementTile(settlement: s),
                ],
              ),
            ),
        },
      ),
    );
  }
}

class _OwedCard extends StatelessWidget {
  const _OwedCard({required this.wallet, required this.onSettle});
  final Wallet wallet;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    final owed = wallet.commissionOwed;
    final clear = owed == 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: clear
              ? const [Color(0xFF12A46B), Color(0xFF0C7E51)]
              : const [Color(0xFFFF5A47), Color(0xFFE81E2D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(clear ? 'All settled' : 'Commission due',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Rs $owed',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(
              clear
                  ? "You're all caught up. Keep earning!"
                  : 'Deposit this to keep your account in good standing.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5)),
          if (!clear) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onSettle,
                style: FilledButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: const Color(0xFFE81E2D)),
                child: const Text('Settle now'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
        ],
      ),
    );
  }
}

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({required this.settlement});
  final Settlement settlement;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF12A46B).withValues(alpha: 0.12),
        child: const Icon(Icons.check_rounded, color: Color(0xFF12A46B)),
      ),
      title: Text('Rs ${settlement.amount}',
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(DateFormat('EEE, d MMM • h:mm a').format(settlement.createdAt),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
      trailing: Text(settlement.method == 'cash_deposit' ? 'Cash' : settlement.method,
          style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
    );
  }
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 40),
          const SizedBox(height: 10),
          const Text('Could not load your wallet'),
          const SizedBox(height: 10),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
