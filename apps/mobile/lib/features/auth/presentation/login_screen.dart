import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth_bloc.dart';
import 'forgot_password_sheet.dart';

/// Yango-style phone-first login: minimal light screen, country-code field,
/// full-width action. The step is derived from AuthState — no local nav state.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) => switch (state) {
            AuthCodeSent() => _OtpView(state: state),
            AuthUnauthenticated() => _LoginView(state: state),
            _ => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: primary,
          ),
          child: const Icon(Icons.directions_car_filled_rounded, size: 24, color: Colors.white),
        ),
        const SizedBox(width: 10),
        const Text('Rideshare PK',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView({required this.state});
  final AuthUnauthenticated state;

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  bool _useEmail = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          const _Logo(),
          const SizedBox(height: 36),
          Text('Log in or sign up',
              style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(
            _useEmail
                ? 'Continue with your email and password'
                : 'Enter your mobile number to get a verification code',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 28),
          if (_useEmail)
            _EmailForm(state: widget.state)
          else
            _PhoneForm(state: widget.state),
          if (!_useEmail) ...[
            const SizedBox(height: 22),
            const _OrDivider(),
          ],
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => setState(() => _useEmail = !_useEmail),
            child: Text(_useEmail ? 'Use mobile number instead' : 'Sign in with email'),
          ),
          if (!_useEmail) ...[
            const SizedBox(height: 32),
            const _FeatureRow(),
          ],
          const SizedBox(height: 28),
          Text(
            'By continuing you agree to our Terms and Privacy Policy.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneForm extends StatefulWidget {
  const _PhoneForm({required this.state});
  final AuthUnauthenticated state;

  @override
  State<_PhoneForm> createState() => _PhoneFormState();
}

class _PhoneFormState extends State<_PhoneForm> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final digits = _controller.text.replaceAll(RegExp(r'\D'), '');
    final local = digits.startsWith('0') ? digits.substring(1) : digits;
    if (!RegExp(r'^3\d{9}$').hasMatch(local)) {
      setState(() => _error = 'Enter a valid mobile number (3XX XXXXXXX)');
      return;
    }
    setState(() => _error = null);
    context.read<AuthBloc>().add(AuthOtpRequested('+92$local'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final error = _error ?? widget.state.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: error != null
                    ? theme.colorScheme.error
                    : const Color(0xFFE7E8EC)),
            boxShadow: const [
              BoxShadow(color: Color(0x0F101828), blurRadius: 20, offset: Offset(0, 10)),
            ],
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 12, 0),
                child: Text('🇵🇰  +92',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
              Container(width: 1, height: 28, color: const Color(0xFFE7E8EC)),
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(
                    hintText: '3XX XXXXXXX',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _submit(),
                ),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 20),
        _GradientButton(
          label: 'Continue',
          loading: widget.state.submitting,
          onPressed: widget.state.submitting ? null : _submit,
        ),
      ],
    );
  }
}

/// Full-width gradient CTA with a soft red glow — the app's primary action look.
class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onPressed, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final enabled = onPressed != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: enabled
              ? const [Color(0xFFFF5A47), Color(0xFFE81E2D)]
              : [primary.withValues(alpha: 0.35), primary.withValues(alpha: 0.35)],
        ),
        boxShadow: enabled
            ? [BoxShadow(color: primary.withValues(alpha: 0.28), blurRadius: 26, offset: const Offset(0, 12))]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onPressed,
          child: Container(
            height: 54,
            alignment: Alignment.center,
            child: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget line() => const Expanded(child: Divider(color: Color(0xFFE7E8EC), thickness: 1));
    return Row(
      children: [
        line(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('or',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        ),
        line(),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _Feature(icon: Icons.verified_user_outlined, label: 'Verified\ndrivers'),
        _Feature(icon: Icons.payments_outlined, label: 'Cash\nonly'),
        _Feature(icon: Icons.favorite_outline_rounded, label: 'Women\nfriendly'),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.07),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 21),
        ),
        const SizedBox(height: 9),
        Text(label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline, fontWeight: FontWeight.w500, height: 1.25)),
      ],
    );
  }
}

class _EmailForm extends StatefulWidget {
  const _EmailForm({required this.state});
  final AuthUnauthenticated state;

  @override
  State<_EmailForm> createState() => _EmailFormState();
}

class _EmailFormState extends State<_EmailForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _obscure = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final bloc = context.read<AuthBloc>();
    if (_register) {
      bloc.add(AuthRegisterSubmitted(
        email: _email.text.trim(),
        password: _password.text,
        name: _name.text.trim().isEmpty ? null : _name.text.trim(),
      ));
    } else {
      bloc.add(AuthEmailLoginSubmitted(_email.text.trim(), _password.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_register) ...[
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name (optional)',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            validator: (v) =>
                RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim())
                    ? null
                    : 'Enter a valid email address',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, size: 20),
              ),
            ),
            validator: (v) => (_register && (v ?? '').length < 8)
                ? 'At least 8 characters'
                : (v ?? '').isEmpty
                    ? 'Enter your password'
                    : null,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (!_register)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showForgotPasswordSheet(context),
                child: const Text('Forgot password?'),
              ),
            ),
          if (widget.state.error != null) ...[
            const SizedBox(height: 8),
            Text(widget.state.error!,
                style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 16),
          _GradientButton(
            label: _register ? 'Create account' : 'Log in',
            loading: widget.state.submitting,
            onPressed: widget.state.submitting ? null : _submit,
          ),
          TextButton(
            onPressed: () => setState(() => _register = !_register),
            child: Text(_register
                ? 'Already have an account? Log in'
                : 'New here? Create an account'),
          ),
        ],
      ),
    );
  }
}

class _OtpView extends StatefulWidget {
  const _OtpView({required this.state});
  final AuthCodeSent state;

  @override
  State<_OtpView> createState() => _OtpViewState();
}

class _OtpViewState extends State<_OtpView> {
  String _code = '';
  Timer? _timer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsLeft = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _verify() {
    if (_code.length == 6) {
      context.read<AuthBloc>().add(AuthOtpSubmitted(_code));
    }
  }

  void _resend() {
    context.read<AuthBloc>().add(AuthOtpRequested(widget.state.phone));
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasError = widget.state.error != null;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
              icon: const Icon(Icons.arrow_back),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
            ),
          ),
          const SizedBox(height: 16),
          Text('Enter verification code',
              style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('We sent a 6-digit code to ${widget.state.phone}',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
          if (widget.state.devCode != null) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                avatar: const Icon(Icons.bug_report_outlined, size: 18),
                label: Text('Dev code: ${widget.state.devCode}'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _OtpBoxes(
            hasError: hasError,
            onChanged: (v) => setState(() => _code = v),
            onCompleted: (v) {
              setState(() => _code = v);
              _verify();
            },
          ),
          if (hasError) ...[
            const SizedBox(height: 14),
            Text(widget.state.error!,
                style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center),
          ],
          const SizedBox(height: 24),
          _GradientButton(
            label: 'Verify',
            loading: widget.state.submitting,
            onPressed: (_code.length == 6 && !widget.state.submitting) ? _verify : null,
          ),
          const SizedBox(height: 8),
          Center(
            child: _secondsLeft > 0
                ? Text('Resend code in 0:${_secondsLeft.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))
                : TextButton(onPressed: _resend, child: const Text('Resend code')),
          ),
          Center(
            child: TextButton(
              onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
              child: const Text('Change number'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpBoxes extends StatefulWidget {
  const _OtpBoxes({
    required this.onChanged,
    required this.onCompleted,
    this.hasError = false,
  });
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;
  final bool hasError;

  @override
  State<_OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<_OtpBoxes> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = _controller.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final filled = i < text.length;
              final active = i == text.length && _focus.hasFocus;
              final borderColor = widget.hasError
                  ? theme.colorScheme.error
                  : active
                      ? theme.colorScheme.primary
                      : filled
                          ? theme.colorScheme.primary.withValues(alpha: 0.45)
                          : const Color(0xFFE7E8EC);
              return Container(
                width: 46,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(color: Color(0x0F101828), blurRadius: 16, offset: Offset(0, 8)),
                  ],
                  border: Border.all(color: borderColor, width: active ? 2 : 1.3),
                ),
                child: Text(filled ? text[i] : '',
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              );
            }),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                keyboardType: TextInputType.number,
                maxLength: 6,
                showCursor: false,
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                onChanged: (v) {
                  final digits = v.replaceAll(RegExp(r'\D'), '');
                  if (digits != v) {
                    _controller.value = TextEditingValue(
                      text: digits,
                      selection: TextSelection.collapsed(offset: digits.length),
                    );
                  }
                  setState(() {});
                  widget.onChanged(digits);
                  if (digits.length == 6) widget.onCompleted(digits);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
