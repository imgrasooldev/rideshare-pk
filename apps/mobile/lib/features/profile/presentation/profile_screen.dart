import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../auth/data/models/user.dart';
import '../../trust/bloc/verifications_cubit.dart';
import '../../vehicles/bloc/vehicles_cubit.dart';
import '../bloc/profile_cubit.dart';
import 'edit_profile_sheet.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MultiBlocListener(
      listeners: [
        BlocListener<ProfileCubit, ProfileState>(
          listener: (context, state) {
            if (state is ProfileSaved) {
              // Keep the app-wide auth user in sync with the edited profile.
              context.read<AuthBloc>().add(AuthProfileRefreshed(state.user));
              context.read<ProfileCubit>().reset();
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Profile updated')));
            } else if (state is ProfileError) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(state.message),
                backgroundColor: theme.colorScheme.error,
              ));
              context.read<ProfileCubit>().reset();
            }
          },
        ),
      ],
      child: ListView(
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
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => showEditProfileSheet(context, user),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
          ),
          const Divider(height: 32),
          _VerificationSection(user: user),
          const Divider(height: 32),
          const _VehiclesSection(),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _VerificationSection extends StatelessWidget {
  const _VerificationSection({required this.user});
  final User user;

  Future<void> _submitCnicDialog(BuildContext context) async {
    final controller = TextEditingController();
    final cubit = context.read<VerificationsCubit>();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('CNIC verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Paste a link to a photo of your CNIC (front). In-app photo upload is coming soon.'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Document URL',
                hintText: 'https://…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Submit')),
        ],
      ),
    );
    if (submitted == true && controller.text.trim().isNotEmpty) {
      await cubit.submit(type: 'cnic', docUrl: controller.text.trim());
    }
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<VerificationsCubit, VerificationsState>(
      builder: (context, state) {
        final items = state is VerificationsLoaded ? state.items : null;
        final pending = state is VerificationsLoaded && state.hasPendingCnic;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verification', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (user.verified)
              const ListTile(
                leading: Icon(Icons.verified, color: Colors.green),
                title: Text('CNIC verified'),
                subtitle: Text('You can post rides'),
                contentPadding: EdgeInsets.zero,
              )
            else if (pending)
              const ListTile(
                leading: Icon(Icons.hourglass_top),
                title: Text('CNIC under review'),
                subtitle: Text('Our team reviews within 24 hours'),
                contentPadding: EdgeInsets.zero,
              )
            else
              ListTile(
                leading: const Icon(Icons.badge_outlined),
                title: const Text('Get verified'),
                subtitle: Text(user.cnicMasked == null
                    ? 'Add your CNIC in Edit profile, then submit your document'
                    : 'Submit your CNIC document (${user.cnicMasked})'),
                trailing: FilledButton.tonal(
                  onPressed:
                      user.cnicMasked == null ? null : () => _submitCnicDialog(context),
                  child: const Text('Submit'),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            if (items != null)
              for (final v in items.where((v) => v.status == 'rejected'))
                ListTile(
                  leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
                  title: Text('${v.type} rejected'),
                  subtitle: Text(v.notes ?? 'Submit a clearer document'),
                  contentPadding: EdgeInsets.zero,
                ),
          ],
        );
      },
    );
  }
}

class _VehiclesSection extends StatelessWidget {
  const _VehiclesSection();

  Future<void> _addVehicleDialog(BuildContext context) async {
    final cubit = context.read<VehiclesCubit>();
    final make = TextEditingController();
    final model = TextEditingController();
    final plate = TextEditingController();
    final seats = TextEditingController(text: '4');
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add vehicle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: make,
                  decoration: const InputDecoration(labelText: 'Make (e.g. Suzuki)')),
              TextField(
                  controller: model,
                  decoration: const InputDecoration(labelText: 'Model (e.g. Alto)')),
              TextField(
                  controller: plate,
                  decoration: const InputDecoration(labelText: 'Plate (e.g. LEB-1234)')),
              TextField(
                controller: seats,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Passenger seats'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add')),
        ],
      ),
    );
    if (submitted == true) {
      await cubit.add(
        make: make.text.trim(),
        model: model.text.trim(),
        plate: plate.text.trim(),
        seats: int.tryParse(seats.text.trim()) ?? 4,
      );
    }
    for (final c in [make, model, plate, seats]) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<VehiclesCubit, VehiclesState>(
      builder: (context, state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('My vehicles', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addVehicleDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          switch (state) {
            VehiclesLoading() => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
            VehiclesError(:final message) => Text(message),
            VehiclesLoaded(:final vehicles) when vehicles.isEmpty =>
              const Text('No vehicles yet.'),
            VehiclesLoaded(:final vehicles) => Column(
                children: [
                  for (final v in vehicles)
                    ListTile(
                      leading: const Icon(Icons.directions_car_outlined),
                      title: Text('${v.make} ${v.model}'),
                      subtitle: Text('${v.plate} · ${v.seats} seats'),
                      trailing: v.verified
                          ? const Icon(Icons.verified, color: Colors.green)
                          : null,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
          },
        ],
      ),
    );
  }
}
