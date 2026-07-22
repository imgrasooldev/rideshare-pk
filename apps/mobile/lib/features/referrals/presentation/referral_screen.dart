import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/referrals_repository.dart';

/// Refer & earn: share your code, see how many joined, and enter a friend's.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  late Future<ReferralSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ReferralsRepository>().me();
  }

  void _reload() => setState(() => _future = context.read<ReferralsRepository>().me());

  Future<void> _applyCode() async {
    final controller = TextEditingController();
    final repo = context.read<ReferralsRepository>();
    final messenger = ScaffoldMessenger.of(context);
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter a referral code'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'e.g. K7QP2M', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Apply')),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    try {
      await repo.apply(code);
      messenger.showSnackBar(const SnackBar(content: Text('Referral applied — thank you!')));
      _reload();
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('That code could not be applied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Refer & earn'), centerTitle: false),
      body: FutureBuilder<ReferralSummary>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.hasData) {
            return Center(
              child: TextButton(onPressed: _reload, child: const Text('Retry')),
            );
          }
          final s = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF5A47), Color(0xFFE81E2D)],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your referral code',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(s.code,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 3)),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: s.code));
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Code copied')));
                          },
                          icon: const Icon(Icons.copy_rounded, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${s.count} friend${s.count == 1 ? '' : 's'} joined with your code',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Share your code with friends. Rewards accrue now and become '
                  'redeemable credit once wallet top-ups launch.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
              const SizedBox(height: 20),
              if (s.referredBy == null)
                OutlinedButton.icon(
                  onPressed: _applyCode,
                  icon: const Icon(Icons.redeem_rounded),
                  label: const Text('I have a referral code'),
                )
              else
                Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    Text('You joined with code ${s.referredBy}',
                        style: theme.textTheme.bodyMedium),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}
