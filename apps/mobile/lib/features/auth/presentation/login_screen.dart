import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';

/// Two-step OTP login. The step is derived from AuthState — no local
/// navigation state to drift out of sync.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: BlocBuilder<AuthBloc, AuthState>(
                builder: (context, state) => switch (state) {
                  AuthCodeSent() => _OtpStep(state: state),
                  AuthUnauthenticated() => _PhoneStep(state: state),
                  _ => const CircularProgressIndicator(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhoneStep extends StatefulWidget {
  const _PhoneStep({required this.state});
  final AuthUnauthenticated state;

  @override
  State<_PhoneStep> createState() => _PhoneStepState();
}

class _PhoneStepState extends State<_PhoneStep> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      context.read<AuthBloc>().add(AuthOtpRequested(_controller.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.directions_car_filled, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text('Rideshare PK',
              textAlign: TextAlign.center, style: theme.textTheme.headlineMedium),
          Text('Share your daily commute',
              textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 32),
          TextFormField(
            controller: _controller,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              hintText: '03XX XXXXXXX',
              prefixIcon: Icon(Icons.phone_android),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
              final ok = RegExp(r'^(?:\+92|0092|92|0)3\d{9}$').hasMatch(digits);
              return ok ? null : 'Enter a valid Pakistani mobile (03XX XXXXXXX)';
            },
            onFieldSubmitted: (_) => _submit(),
          ),
          if (widget.state.error != null) ...[
            const SizedBox(height: 12),
            Text(widget.state.error!,
                style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: widget.state.submitting ? null : _submit,
            child: widget.state.submitting
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Send code'),
          ),
        ],
      ),
    );
  }
}

class _OtpStep extends StatefulWidget {
  const _OtpStep({required this.state});
  final AuthCodeSent state;

  @override
  State<_OtpStep> createState() => _OtpStepState();
}

class _OtpStepState extends State<_OtpStep> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().length == 6) {
      context.read<AuthBloc>().add(AuthOtpSubmitted(_controller.text.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.sms_outlined, size: 56, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text('Enter the 6-digit code',
            textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
        Text('Sent to ${widget.state.phone}',
            textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        if (widget.state.devCode != null) ...[
          const SizedBox(height: 8),
          Chip(
            avatar: const Icon(Icons.bug_report, size: 18),
            label: Text('Dev code: ${widget.state.devCode}'),
          ),
        ],
        const SizedBox(height: 24),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 12),
          decoration: const InputDecoration(counterText: '', border: OutlineInputBorder()),
          onSubmitted: (_) => _submit(),
          onChanged: (v) {
            if (v.length == 6) _submit();
          },
        ),
        if (widget.state.error != null) ...[
          const SizedBox(height: 12),
          Text(widget.state.error!,
              style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: widget.state.submitting ? null : _submit,
          child: widget.state.submitting
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Verify'),
        ),
        TextButton(
          onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
          child: const Text('Change number'),
        ),
      ],
    );
  }
}
