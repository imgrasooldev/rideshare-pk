import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/widgets/empty_state.dart';
import '../bloc/threads_cubit.dart';
import '../data/messages_repository.dart';
import 'chat_screen.dart';

/// The conversations inbox — every ride thread the user is part of.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ThreadsCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages'), centerTitle: false),
      body: RefreshIndicator(
        onRefresh: () => context.read<ThreadsCubit>().load(),
        child: BlocBuilder<ThreadsCubit, ThreadsState>(
          builder: (context, state) => switch (state) {
            ThreadsLoading() => const Center(child: CircularProgressIndicator()),
            ThreadsFailed(:final message) => ListView(children: [
                const SizedBox(height: 120),
                EmptyState(
                  icon: Icons.wifi_off_rounded,
                  title: 'Something went wrong',
                  message: message,
                  isError: true,
                  action: TextButton(
                    onPressed: () => context.read<ThreadsCubit>().load(),
                    child: const Text('Retry'),
                  ),
                ),
              ]),
            ThreadsLoaded(:final threads) when threads.isEmpty => ListView(children: const [
                SizedBox(height: 120),
                EmptyState(
                  icon: Icons.forum_outlined,
                  title: 'No messages yet',
                  message: 'Message a driver from a ride to start a conversation.',
                ),
              ]),
            ThreadsLoaded(:final threads) => ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: threads.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
                itemBuilder: (context, i) => _ThreadTile(thread: threads[i]),
              ),
          },
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread});
  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = (thread.otherName?.trim().isNotEmpty ?? false)
        ? thread.otherName!.trim()
        : 'Rider';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final route = '${thread.originLabel} → ${thread.destLabel}';
    final unread = thread.unread > 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        child: Text(initial,
            style: TextStyle(
                color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
          ),
          Text(DateFormat('d MMM').format(thread.lastAt),
              style: theme.textTheme.labelSmall?.copyWith(
                  color: unread ? theme.colorScheme.primary : theme.colorScheme.outline,
                  fontWeight: unread ? FontWeight.w700 : null)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(route,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${thread.lastFromMe ? 'You: ' : ''}${thread.lastBody}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: unread
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.outline,
                      fontWeight: unread ? FontWeight.w700 : null),
                ),
              ),
              if (unread)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text('${thread.unread}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        ],
      ),
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            rideId: thread.rideId,
            otherId: thread.otherId,
            title: name,
            subtitle: route,
          ),
        ));
        if (context.mounted) context.read<ThreadsCubit>().load();
      },
    );
  }
}
