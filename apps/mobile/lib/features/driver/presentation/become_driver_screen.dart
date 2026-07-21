import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/bloc/auth_bloc.dart';
import '../../auth/data/auth_repository.dart';
import '../../rides/data/rides_repository.dart'
    show vehicleTypes, vehicleTypeIcon, vehicleTypeLabel;
import '../../vehicles/bloc/vehicles_cubit.dart';
import '../../vehicles/data/vehicles_repository.dart';
import '../bloc/my_rides_cubit.dart';
import 'post_ride_screen.dart';

/// Turns a rider into a provider: add a vehicle, flip the account to a driver
/// (role "both"), and hand off to posting the first ride.
class BecomeDriverScreen extends StatefulWidget {
  const BecomeDriverScreen({super.key});

  @override
  State<BecomeDriverScreen> createState() => _BecomeDriverScreenState();
}

class _BecomeDriverScreenState extends State<BecomeDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _plate = TextEditingController();
  String _type = 'car';
  int _seats = 4;
  bool _busy = false;
  String? _error;

  int get _maxSeats => _type == 'bike' ? 1 : _type == 'hiace' ? 14 : _type == 'minivan' ? 8 : 4;

  void _pickType(String t) {
    setState(() {
      _type = t;
      _seats = t == 'bike' ? 1 : t == 'hiace' ? 12 : t == 'minivan' ? 7 : 4;
    });
  }

  @override
  void dispose() {
    _make.dispose();
    _model.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Capture everything context-bound before the async gaps.
    final vehicles = context.read<VehiclesRepository>();
    final auth = context.read<AuthRepository>();
    final authBloc = context.read<AuthBloc>();
    final vehiclesCubit = context.read<VehiclesCubit>();
    final myRides = context.read<MyRidesCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      // 1) Register the vehicle.
      await vehicles.create(
        make: _make.text.trim(),
        model: _model.text.trim(),
        plate: _plate.text.trim(),
        seats: _seats,
        vehicleType: _type,
      );
      // 2) Flip the account to a driver (keeps rider abilities → role "both").
      final user = await auth.updateProfile(role: 'both');
      if (!mounted) return;
      // 3) Refresh session everywhere: unlocks the Drive tab, profile, my rides.
      authBloc.add(AuthProfileRefreshed(user));
      vehiclesCubit.load();
      myRides.load();
      messenger.showSnackBar(
        const SnackBar(content: Text("You're a driver now — offer your first ride!")),
      );
      // 4) Straight into posting a ride.
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const PostRideScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not complete — please check the details and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Offer your car')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _Hero(theme: theme),
            const SizedBox(height: 20),
            Text('Your vehicle',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final t in vehicleTypes)
                  ChoiceChip(
                    avatar: Icon(vehicleTypeIcon(t), size: 16),
                    label: Text(vehicleTypeLabel(t)),
                    selected: _type == t,
                    onSelected: (_) => _pickType(t),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _make,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Make', hintText: 'Toyota'),
                    validator: (v) => (v ?? '').trim().length < 2 ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _model,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Model', hintText: 'Corolla'),
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Number plate', hintText: 'LEA-1786'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Enter your plate' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Seats for riders',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                _Stepper(
                  value: _seats,
                  min: 1,
                  max: _maxSeats,
                  onChanged: (v) => setState(() => _seats = v),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!,
                  textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Become a driver'),
            ),
            const SizedBox(height: 10),
            Text(
              'You stay a rider too — book rides and offer your car from the same account.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.theme});
  final ThemeData theme;
  @override
  Widget build(BuildContext context) {
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF5A47), Color(0xFFE81E2D)],
        ),
        boxShadow: [
          BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 22, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.directions_car_filled_rounded, color: Colors.white, size: 30),
          const SizedBox(height: 12),
          const Text('Turn empty seats into income',
              style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Already commuting? Offer the spare seats in your car and share the cost — cash, verified riders.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12.5, height: 1.4)),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.min, required this.max, required this.onChanged});
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget btn(IconData icon, VoidCallback? onTap) => InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Icon(icon, size: 18,
                color: onTap == null ? theme.colorScheme.outlineVariant : theme.colorScheme.primary),
          ),
        );
    return Row(
      children: [
        btn(Icons.remove, value > min ? () => onChanged(value - 1) : null),
        SizedBox(
          width: 40,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        btn(Icons.add, value < max ? () => onChanged(value + 1) : null),
      ],
    );
  }
}
