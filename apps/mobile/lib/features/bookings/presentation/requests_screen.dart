import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/widgets/empty_state.dart';
import '../bloc/requests_cubit.dart';
import '../data/models/seat_request.dart';

/// Driver dispatch inbox — accept, reject, or counter-offer seat requests.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<RequestsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seat requests'), centerTitle: false),
      body: RefreshIndicator(
        onRefresh: () => context.read<RequestsCubit>().load(),
        child: BlocBuilder<RequestsCubit, RequestsState>(
          builder: (context, state) => switch (state) {
            RequestsLoading() => const Center(child: CircularProgressIndicator()),
            RequestsFailed() => ListView(children: [
                const SizedBox(height: 120),
                EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Could not load requests',
                  message: 'Pull to retry.',
                  isError: true,
                ),
              ]),
            RequestsLoaded(:final requests) when requests.isEmpty =>
              ListView(children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No pending requests',
                  message: 'When riders request a seat on your rides, they show up here.',
                ),
              ]),
            RequestsLoaded(:final requests, :final busyId) => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) =>
                    _RequestCard(request: requests[i], busy: busyId == requests[i].id),
              ),
          },
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.busy});
  final SeatRequest request;
  final bool busy;

  Future<void> _counter(BuildContext context) async {
    final controller =
        TextEditingController(text: '${request.pricePerSeat ?? ''}');
    final cubit = context.read<RequestsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final price = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Counter-offer'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            prefixText: 'Rs ',
            labelText: 'Price per seat',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(controller.text.trim()) ?? 0),
            child: const Text('Send offer'),
          ),
        ],
      ),
    );
    if (price == null || price <= 0) return;
    final err = await cubit.counter(request.id, price);
    if (err != null) messenger.showSnackBar(SnackBar(content: Text(err)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countered = request.status == 'countered';
    final name = (request.riderName?.trim().isNotEmpty ?? false)
        ? request.riderName!.trim()
        : 'A rider';
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Text(name[0].toUpperCase(),
                      style: TextStyle(
                          color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text('${request.seats} seat${request.seats > 1 ? 's' : ''}'
                          '${request.departAt != null ? ' · ${DateFormat('EEE, d MMM • h:mm a').format(request.departAt!)}' : ''}',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
                if (countered)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF3D6),
                        borderRadius: BorderRadius.circular(999)),
                    child: const Text('Offer sent',
                        style: TextStyle(
                            color: Color(0xFFB77400),
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text('${request.originLabel ?? ''} → ${request.destLabel ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              countered
                  ? 'Your offer: Rs ${request.offeredPrice}/seat (asked Rs ${request.pricePerSeat})'
                  : 'Rs ${request.pricePerSeat ?? '—'}/seat',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 14),
            if (busy)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(6),
                child: SizedBox(
                    width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
              ))
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.read<RequestsCubit>().reject(request.id),
                      style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!countered)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _counter(context),
                        child: const Text('Counter'),
                      ),
                    ),
                  if (!countered) const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => context.read<RequestsCubit>().accept(request.id),
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
