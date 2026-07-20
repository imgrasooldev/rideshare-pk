import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../auth/bloc/auth_bloc.dart';
import '../../rides/data/rides_repository.dart';
import '../bloc/post_ride_cubit.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class PostRideScreen extends StatefulWidget {
  const PostRideScreen({super.key});

  @override
  State<PostRideScreen> createState() => _PostRideScreenState();
}

class _PostRideScreenState extends State<PostRideScreen> {
  Hub _origin = lahoreHubs[1];
  Hub _dest = lahoreHubs[0];
  DateTime _departAt = _nextMorning();
  final Set<int> _days = {1, 2, 3, 4, 5}; // Mon–Fri
  int _seats = 3;
  bool _ladiesOnly = false;
  String _vehicleType = 'car';
  final _priceController = TextEditingController(text: '250');

  int get _maxSeats => switch (_vehicleType) {
        'bike' => 1,
        'hiace' => 18,
        'minivan' => 10,
        _ => 6,
      };

  static DateTime _nextMorning() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8);
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickDepartAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _departAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_departAt),
    );
    if (time == null) return;
    setState(() =>
        _departAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  void _submit() {
    final price = int.tryParse(_priceController.text.trim());
    if (price == null || price < 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid price per seat')));
      return;
    }
    context.read<PostRideCubit>().submit(
          origin: _origin,
          dest: _dest,
          departAt: _departAt,
          recurringDays: (_days.toList()..sort()).map((d) => d % 7).toList(),
          seatsTotal: _seats,
          pricePerSeat: price,
          vehicleType: _vehicleType,
          ladiesOnly: _ladiesOnly,
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final isFemale = auth is AuthAuthenticated && auth.user.gender == 'female';

    return BlocListener<PostRideCubit, PostRideState>(
      listener: (context, state) {
        if (state is PostRideSuccess) {
          context.read<PostRideCubit>().reset();
          Navigator.of(context).pop(true);
        } else if (state is PostRideFailure) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.message),
            backgroundColor: Theme.of(context).colorScheme.error,
          ));
          context.read<PostRideCubit>().reset();
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Post a ride')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<Hub>(
              initialValue: _origin,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'From', border: OutlineInputBorder()),
              items: [
                for (final h in lahoreHubs) DropdownMenuItem(value: h, child: Text(h.label)),
              ],
              onChanged: (h) => setState(() => _origin = h ?? _origin),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Hub>(
              initialValue: _dest,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'To', border: OutlineInputBorder()),
              items: [
                for (final h in lahoreHubs) DropdownMenuItem(value: h, child: Text(h.label)),
              ],
              onChanged: (h) => setState(() => _dest = h ?? _dest),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDepartAt,
              icon: const Icon(Icons.schedule),
              label: Text(DateFormat('EEE, d MMM • h:mm a').format(_departAt)),
            ),
            const SizedBox(height: 16),
            Text('Vehicle', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final type in vehicleTypes)
                  ChoiceChip(
                    avatar: Icon(vehicleTypeIcon(type), size: 16),
                    label: Text(vehicleTypeLabel(type)),
                    selected: _vehicleType == type,
                    onSelected: (_) => setState(() {
                      _vehicleType = type;
                      if (_seats > _maxSeats) _seats = _maxSeats;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Repeats on', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (var i = 1; i <= 7; i++)
                  FilterChip(
                    label: Text(_weekdays[i - 1]),
                    selected: _days.contains(i),
                    onSelected: (on) =>
                        setState(() => on ? _days.add(i) : _days.remove(i)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Seats', style: Theme.of(context).textTheme.labelLarge),
                const Spacer(),
                IconButton(
                  onPressed: _seats > 1 ? () => setState(() => _seats--) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_seats', style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  onPressed: _seats < _maxSeats ? () => setState(() => _seats++) : null,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Price per seat (PKR, fuel cost-share)',
                prefixText: 'Rs ',
                helperText: 'Paid in cash to you — no app payments yet',
                border: OutlineInputBorder(),
              ),
            ),
            if (isFemale) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                title: const Text('Ladies only'),
                subtitle: const Text('Only women can see and book this ride'),
                value: _ladiesOnly,
                onChanged: (v) => setState(() => _ladiesOnly = v),
              ),
            ],
            const SizedBox(height: 24),
            BlocBuilder<PostRideCubit, PostRideState>(
              builder: (context, state) => FilledButton(
                onPressed: state is PostRideSubmitting ? null : _submit,
                child: Text(state is PostRideSubmitting ? 'Posting…' : 'Post ride'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
