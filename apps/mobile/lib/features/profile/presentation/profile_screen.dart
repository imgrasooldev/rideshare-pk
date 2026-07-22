import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../auth/data/models/user.dart';
import '../../rides/data/rides_repository.dart'
    show vehicleTypeIcon, vehicleTypeLabel, vehicleTypes;
import '../../trust/bloc/verifications_cubit.dart';
import '../../vehicles/bloc/vehicles_cubit.dart';
import '../../subscriptions/presentation/subscriptions_screen.dart';
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  Color.lerp(theme.colorScheme.primary, Colors.black, 0.35)!,
                ],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: Text(
                        user.handle[0].toUpperCase(),
                        style: theme.textTheme.headlineSmall?.copyWith(
                            color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name ?? 'Add your name',
                              style: theme.textTheme.titleLarge?.copyWith(
                                  color: Colors.white, fontWeight: FontWeight.w800)),
                          Text(user.phone ?? user.email ?? 'Add a phone number',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => showEditProfileSheet(context, user),
                      icon: const Icon(Icons.edit_outlined, color: Colors.white),
                      tooltip: 'Edit profile',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _HeaderBadge(
                      icon: user.verified ? Icons.verified : Icons.hourglass_empty,
                      label: user.verified ? 'Verified' : 'Not verified',
                    ),
                    const SizedBox(width: 8),
                    _HeaderBadge(icon: Icons.badge_outlined, label: user.role),
                    const SizedBox(width: 8),
                    _HeaderBadge(icon: Icons.location_city_rounded, label: user.city),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: () => showEditProfileSheet(context, user),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit profile'),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _VerificationSection(user: user),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const _VehiclesSection(),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: Icon(Icons.event_repeat_rounded, color: theme.colorScheme.primary),
              title: const Text('My subscriptions'),
              subtitle: const Text("Monthly routes you're subscribed to"),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SubscriptionsScreen()),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: _EmergencyContactTile(user: user),
          ),
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

/// Safety: the trusted contact alerted (by SMS with live location) on an SOS.
class _EmergencyContactTile extends StatelessWidget {
  const _EmergencyContactTile({required this.user});
  final User user;

  Future<void> _edit(BuildContext context) async {
    final controller = TextEditingController(text: user.emergencyPhone ?? '');
    final cubit = context.read<ProfileCubit>();
    final phone = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emergency contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('We SMS this number your live location if you trigger SOS.',
                style: Theme.of(ctx).textTheme.bodySmall),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                prefixText: '+92 ',
                labelText: 'Mobile number',
                hintText: '3XX XXXXXXX',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (phone == null || phone.isEmpty) return;
    // Normalise a local 03xx / 3xx number to E.164 for the backend.
    var e164 = phone.replaceAll(RegExp(r'[\s-]'), '');
    if (e164.startsWith('0')) e164 = e164.substring(1);
    if (!e164.startsWith('+')) e164 = '+92$e164';
    cubit.save(emergencyPhone: e164);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final set = (user.emergencyPhone?.trim().isNotEmpty ?? false);
    return ListTile(
      leading: Icon(Icons.health_and_safety_outlined, color: theme.colorScheme.primary),
      title: const Text('Emergency contact'),
      subtitle: Text(set
          ? user.emergencyPhone!
          : 'Add a trusted contact for SOS alerts'),
      trailing: Text(set ? 'Edit' : 'Add',
          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
      onTap: () => _edit(context),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _VerificationSection extends StatelessWidget {
  const _VerificationSection({required this.user});
  final User user;

  /// Snap or pick the CNIC photo, then upload it straight to private storage.
  Future<void> _submitCnicDialog(BuildContext context) async {
    final cubit = context.read<VerificationsCubit>();
    final messenger = ScaffoldMessenger.of(context);

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Photograph the front of your CNIC. Make sure all four corners are '
                'visible and the text is readable.',
                textAlign: TextAlign.center,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    // Downscale before upload: CNIC text stays legible well under 1600px,
    // and riders on patchy mobile data should not push 8MP originals.
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > 8 * 1024 * 1024) {
      messenger.showSnackBar(
        const SnackBar(content: Text('That image is too large — please retake it.')),
      );
      return;
    }

    await cubit.uploadAndSubmit(
      type: 'cnic',
      bytes: bytes,
      contentType: picked.mimeType ?? 'image/jpeg',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return BlocBuilder<VerificationsCubit, VerificationsState>(
      builder: (context, state) {
        final items = state is VerificationsLoaded ? state.items : null;
        final pending = state is VerificationsLoaded && state.hasPendingCnic;
        final busy = state is VerificationsLoaded && state.submitting;
        final progress = state is VerificationsLoaded ? state.uploadProgress : null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Verification', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (busy)
              ListTile(
                leading: const Icon(Icons.cloud_upload_outlined),
                title: Text(progress == null
                    ? 'Submitting…'
                    : 'Uploading document… ${(progress * 100).round()}%'),
                subtitle: LinearProgressIndicator(value: progress),
                contentPadding: EdgeInsets.zero,
              )
            else if (user.verified)
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
    var type = 'car';
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Add vehicle'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final t in vehicleTypes)
                      DropdownMenuItem(
                        value: t,
                        child: Row(children: [
                          Icon(vehicleTypeIcon(t), size: 18),
                          const SizedBox(width: 8),
                          Text(vehicleTypeLabel(t)),
                        ]),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() {
                    type = v ?? 'car';
                    if (type == 'bike') seats.text = '1';
                    if (type == 'hiace') seats.text = '12';
                    if (type == 'minivan') seats.text = '7';
                    if (type == 'car') seats.text = '4';
                  }),
                ),
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
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (submitted == true) {
      await cubit.add(
        make: make.text.trim(),
        model: model.text.trim(),
        plate: plate.text.trim(),
        seats: int.tryParse(seats.text.trim()) ?? 4,
        vehicleType: type,
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
                      leading: Icon(vehicleTypeIcon(v.vehicleType)),
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
