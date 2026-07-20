import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../auth/data/models/user.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        CircleAvatar(
          radius: 40,
          child: Text(
            (user.name?.isNotEmpty == true ? user.name![0] : user.phone.substring(3, 4))
                .toUpperCase(),
            style: theme.textTheme.headlineMedium,
          ),
        ),
        const SizedBox(height: 12),
        Text(user.name ?? 'Add your name',
            textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        Text(user.phone, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            Chip(
              avatar: Icon(
                user.verified ? Icons.verified : Icons.hourglass_empty,
                size: 18,
                color: user.verified ? Colors.green.shade700 : null,
              ),
              label: Text(user.verified ? 'Verified' : 'Not verified'),
            ),
            Chip(label: Text(user.role)),
            Chip(label: Text(user.city)),
          ],
        ),
        const Divider(height: 40),
        ListTile(
          leading: const Icon(Icons.badge_outlined),
          title: const Text('CNIC'),
          subtitle: Text(user.cnicMasked ?? 'Not provided'),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ],
    );
  }
}
