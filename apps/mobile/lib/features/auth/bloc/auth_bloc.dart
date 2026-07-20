import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../data/models/user.dart';

// ---------- Events ----------

sealed class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

/// App start: try to restore a persisted session.
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

final class AuthOtpRequested extends AuthEvent {
  const AuthOtpRequested(this.phone);
  final String phone;
  @override
  List<Object?> get props => [phone];
}

final class AuthOtpSubmitted extends AuthEvent {
  const AuthOtpSubmitted(this.code);
  final String code;
  @override
  List<Object?> get props => [code];
}

final class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

final class AuthProfileRefreshed extends AuthEvent {
  const AuthProfileRefreshed(this.user);
  final User user;
  @override
  List<Object?> get props => [user];
}

// ---------- States ----------

sealed class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

final class AuthRestoring extends AuthState {
  const AuthRestoring();
}

final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.submitting = false, this.error});
  final bool submitting;
  final String? error;
  @override
  List<Object?> get props => [submitting, error];
}

final class AuthCodeSent extends AuthState {
  const AuthCodeSent({
    required this.phone,
    this.devCode,
    this.submitting = false,
    this.error,
  });

  final String phone;

  /// Present only when the backend is in OTP dev mode — shown as a testing aid.
  final String? devCode;
  final bool submitting;
  final String? error;

  AuthCodeSent copyWith({bool? submitting, String? error}) => AuthCodeSent(
        phone: phone,
        devCode: devCode,
        submitting: submitting ?? this.submitting,
        error: error,
      );

  @override
  List<Object?> get props => [phone, devCode, submitting, error];
}

final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final User user;
  @override
  List<Object?> get props => [user];
}

// ---------- Bloc ----------

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._repo) : super(const AuthRestoring()) {
    on<AuthStarted>(_onStarted);
    on<AuthOtpRequested>(_onOtpRequested);
    on<AuthOtpSubmitted>(_onOtpSubmitted);
    on<AuthLogoutRequested>(_onLogout);
    on<AuthProfileRefreshed>((event, emit) => emit(AuthAuthenticated(event.user)));
  }

  final AuthRepository _repo;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    final user = await _repo.restoreSession();
    emit(user != null ? AuthAuthenticated(user) : const AuthUnauthenticated());
  }

  Future<void> _onOtpRequested(AuthOtpRequested event, Emitter<AuthState> emit) async {
    emit(const AuthUnauthenticated(submitting: true));
    try {
      final devCode = await _repo.requestOtp(event.phone);
      emit(AuthCodeSent(phone: event.phone, devCode: devCode));
    } on ApiException catch (e) {
      emit(AuthUnauthenticated(error: e.message));
    }
  }

  Future<void> _onOtpSubmitted(AuthOtpSubmitted event, Emitter<AuthState> emit) async {
    final current = state;
    if (current is! AuthCodeSent) return;
    emit(current.copyWith(submitting: true, error: null));
    try {
      final user = await _repo.verifyOtp(current.phone, event.code);
      emit(AuthAuthenticated(user));
    } on ApiException catch (e) {
      emit(current.copyWith(submitting: false, error: e.message));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _repo.logout();
    emit(const AuthUnauthenticated());
  }
}
