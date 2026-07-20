import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../auth/data/models/user.dart';
import '../bloc/profile_cubit.dart';

Future<void> showEditProfileSheet(BuildContext context, User user) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => BlocProvider.value(
      value: context.read<ProfileCubit>(),
      child: _EditProfileForm(user: user),
    ),
  );
}

class _EditProfileForm extends StatefulWidget {
  const _EditProfileForm({required this.user});
  final User user;

  @override
  State<_EditProfileForm> createState() => _EditProfileFormState();
}

class _EditProfileFormState extends State<_EditProfileForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.user.name ?? '');
  final TextEditingController _cnic = TextEditingController();
  late String _role = widget.user.role;
  late String? _gender = widget.user.gender;

  @override
  void dispose() {
    _name.dispose();
    _cnic.dispose();
    super.dispose();
  }

  void _save() {
    final cnic = _cnic.text.trim();
    context.read<ProfileCubit>().save(
          name: _name.text.trim().isEmpty ? null : _name.text.trim(),
          role: _role,
          gender: _gender,
          cnic: cnic.isEmpty ? null : cnic,
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Edit profile', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Full name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(
              labelText: 'I want to',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'rider', child: Text('Find rides (rider)')),
              DropdownMenuItem(value: 'driver', child: Text('Offer rides (driver)')),
              DropdownMenuItem(value: 'both', child: Text('Both')),
            ],
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _gender,
            decoration: const InputDecoration(
              labelText: 'Gender (needed for ladies-only rides)',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: null, child: Text('Prefer not to say')),
              DropdownMenuItem(value: 'female', child: Text('Female')),
              DropdownMenuItem(value: 'male', child: Text('Male')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _gender = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cnic,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'CNIC',
              hintText: widget.user.cnicMasked ?? '35202-1234567-1',
              helperText: 'Stored encrypted. Needed for driver verification.',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          BlocBuilder<ProfileCubit, ProfileState>(
            builder: (context, state) => FilledButton(
              onPressed: state is ProfileSaving ? null : _save,
              child: Text(state is ProfileSaving ? 'Saving…' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }
}
