import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/data/models/user.dart';

sealed class ProfileState extends Equatable {
  const ProfileState();
  @override
  List<Object?> get props => [];
}

final class ProfileIdle extends ProfileState {
  const ProfileIdle();
}

final class ProfileSaving extends ProfileState {
  const ProfileSaving();
}

final class ProfileSaved extends ProfileState {
  const ProfileSaved(this.user);
  final User user;
  @override
  List<Object?> get props => [user];
}

final class ProfileError extends ProfileState {
  const ProfileError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._auth) : super(const ProfileIdle());

  final AuthRepository _auth;

  Future<void> save(
      {String? name, String? role, String? gender, String? cnic, String? emergencyPhone}) async {
    emit(const ProfileSaving());
    try {
      final user = await _auth.updateProfile(
          name: name, role: role, gender: gender, cnic: cnic, emergencyPhone: emergencyPhone);
      emit(ProfileSaved(user));
    } on ApiException catch (e) {
      emit(ProfileError(e.message));
    }
  }

  void reset() => emit(const ProfileIdle());
}
