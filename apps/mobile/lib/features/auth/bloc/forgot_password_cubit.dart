import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';

sealed class ForgotPasswordState extends Equatable {
  const ForgotPasswordState();
  @override
  List<Object?> get props => [];
}

final class ForgotIdle extends ForgotPasswordState {
  const ForgotIdle({this.error});
  final String? error;
  @override
  List<Object?> get props => [error];
}

final class ForgotSubmitting extends ForgotPasswordState {
  const ForgotSubmitting();
}

/// A reset token was issued (shown in dev mode; e-mailed in production).
final class ForgotCodeSent extends ForgotPasswordState {
  const ForgotCodeSent({required this.email, this.devToken, this.error});
  final String email;
  final String? devToken;
  final String? error;

  ForgotCodeSent copyWith({String? error}) =>
      ForgotCodeSent(email: email, devToken: devToken, error: error);

  @override
  List<Object?> get props => [email, devToken, error];
}

final class ForgotResetting extends ForgotPasswordState {
  const ForgotResetting();
}

final class ForgotDone extends ForgotPasswordState {
  const ForgotDone();
}

class ForgotPasswordCubit extends Cubit<ForgotPasswordState> {
  ForgotPasswordCubit(this._repo) : super(const ForgotIdle());

  final AuthRepository _repo;
  ForgotCodeSent? _sent;

  Future<void> request(String email) async {
    emit(const ForgotSubmitting());
    try {
      final devToken = await _repo.forgotPassword(email);
      _sent = ForgotCodeSent(email: email, devToken: devToken);
      emit(_sent!);
    } on ApiException catch (e) {
      emit(ForgotIdle(error: e.message));
    }
  }

  Future<void> reset({required String token, required String password}) async {
    emit(const ForgotResetting());
    try {
      await _repo.resetPassword(token: token, password: password);
      emit(const ForgotDone());
    } on ApiException catch (e) {
      emit((_sent ?? const ForgotCodeSent(email: '')).copyWith(error: e.message));
    }
  }
}
