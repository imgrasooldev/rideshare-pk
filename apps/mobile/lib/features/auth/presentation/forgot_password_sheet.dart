import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/forgot_password_cubit.dart';
import '../data/auth_repository.dart';

Future<void> showForgotPasswordSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => BlocProvider(
      create: (_) => ForgotPasswordCubit(context.read<AuthRepository>()),
      child: const _ForgotPasswordFlow(),
    ),
  );
}

class _ForgotPasswordFlow extends StatefulWidget {
  const _ForgotPasswordFlow();

  @override
  State<_ForgotPasswordFlow> createState() => _ForgotPasswordFlowState();
}

class _ForgotPasswordFlowState extends State<_ForgotPasswordFlow> {
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: BlocConsumer<ForgotPasswordCubit, ForgotPasswordState>(
        listener: (context, state) {
          if (state is ForgotCodeSent && state.devToken != null &&
              _token.text.isEmpty) {
            _token.text = state.devToken!; // dev convenience — prefill
          }
          if (state is ForgotDone) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Password updated — log in with your new password')));
          }
        },
        builder: (context, state) {
          final busy = state is ForgotSubmitting || state is ForgotResetting;
          final sent = state is ForgotCodeSent;
          final error = switch (state) {
            ForgotIdle(:final error) => error,
            ForgotCodeSent(:final error) => error,
            _ => null,
          };

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Reset password',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                sent
                    ? 'Enter the reset code and choose a new password.'
                    : 'Tell us your account email and we will send a reset code.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 16),
              if (!sent)
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                )
              else ...[
                TextField(
                  controller: _token,
                  decoration: const InputDecoration(
                    labelText: 'Reset code',
                    prefixIcon: Icon(Icons.key_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New password (min 8 characters)',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error,
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy
                    ? null
                    : () {
                        final cubit = context.read<ForgotPasswordCubit>();
                        if (!sent) {
                          if (_email.text.trim().isNotEmpty) {
                            cubit.request(_email.text.trim());
                          }
                        } else {
                          if (_token.text.trim().length >= 20 &&
                              _password.text.length >= 8) {
                            cubit.reset(
                                token: _token.text.trim(), password: _password.text);
                          }
                        }
                      },
                child: Text(busy
                    ? 'Working…'
                    : sent
                        ? 'Set new password'
                        : 'Send reset code'),
              ),
            ],
          );
        },
      ),
    );
  }
}
