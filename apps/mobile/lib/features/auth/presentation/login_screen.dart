import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';

/// Two-step OTP login on a branded gradient backdrop. The step is derived
/// from AuthState — no local navigation state to drift out of sync.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary,
              Color.lerp(scheme.primary, Colors.black, 0.45)!,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Brand(onPrimary: scheme.onPrimary),
                    const SizedBox(height: 28),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                        child: BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) => AnimatedSize(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOut,
                            child: switch (state) {
                              AuthCodeSent() => _OtpStep(state: state),
                              AuthUnauthenticated() => _PhoneStep(state: state),
                              _ => const Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Cost-sharing between commuters.\nSafe, verified, women-friendly.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onPrimary.withValues(alpha: 0.75)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.onPrimary});
  final Color onPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: onPrimary.withValues(alpha: 0.14),
            border: Border.all(color: onPrimary.withValues(alpha: 0.35)),
          ),
          child: Icon(Icons.directions_car_filled_rounded, size: 40, color: onPrimary),
        ),
        const SizedBox(height: 14),
        Text('Rideshare PK',
            style: theme.textTheme.headlineMedium
                ?.copyWith(color: onPrimary, fontWeight: FontWeight.w800)),
        Text('Share your daily commute',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: onPrimary.withValues(alpha: 0.85))),
      ],
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
          Text('Welcome',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Log in or create an account with your mobile number',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _controller,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            decoration: const InputDecoration(
              labelText: 'Mobile number',
              hintText: '03XX XXXXXXX',
              prefixIcon: Icon(Icons.phone_android),
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
                ? const SizedBox.square(
                    dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
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
        Text('Enter the 6-digit code',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Sent to ${widget.state.phone}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        if (widget.state.devCode != null) ...[
          const SizedBox(height: 12),
          Align(
            child: Chip(
              avatar: const Icon(Icons.bug_report, size: 18),
              label: Text('Dev code: ${widget.state.devCode}'),
            ),
          ),
        ],
        const SizedBox(height: 20),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          autofocus: true,
          style: theme.textTheme.headlineSmall?.copyWith(letterSpacing: 12),
          decoration: const InputDecoration(counterText: ''),
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
              ? const SizedBox.square(
                  dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
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
