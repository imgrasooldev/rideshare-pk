import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/models/verification.dart';
import '../data/trust_repository.dart';

sealed class VerificationsState extends Equatable {
  const VerificationsState();
  @override
  List<Object?> get props => [];
}

final class VerificationsLoading extends VerificationsState {
  const VerificationsLoading();
}

final class VerificationsLoaded extends VerificationsState {
  const VerificationsLoaded(
    this.items, {
    this.submitting = false,
    this.error,
    this.uploadProgress,
  });

  final List<Verification> items;
  final bool submitting;
  final String? error;

  /// 0.0–1.0 while the photo uploads; null when not uploading.
  final double? uploadProgress;

  bool get hasPendingCnic => items.any((v) => v.type == 'cnic' && v.status == 'pending');

  @override
  List<Object?> get props => [items, submitting, error, uploadProgress];
}

final class VerificationsError extends VerificationsState {
  const VerificationsError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class VerificationsCubit extends Cubit<VerificationsState> {
  VerificationsCubit(this._repo) : super(const VerificationsLoading());

  final TrustRepository _repo;

  Future<void> load() async {
    emit(const VerificationsLoading());
    try {
      emit(VerificationsLoaded(await _repo.mine()));
    } on ApiException catch (e) {
      emit(VerificationsError(e.message));
    }
  }

  Future<void> submit({
    required String type,
    String? docUrl,
    String? docKey,
    String? vehicleId,
  }) async {
    final current = state;
    final existing = current is VerificationsLoaded ? current.items : <Verification>[];
    emit(VerificationsLoaded(existing, submitting: true));
    try {
      final v = await _repo.submit(
        type: type,
        docUrl: docUrl,
        docKey: docKey,
        vehicleId: vehicleId,
      );
      emit(VerificationsLoaded([v, ...existing]));
    } on ApiException catch (e) {
      emit(VerificationsLoaded(existing, error: e.message));
    }
  }

  /// Capture-to-submit in one step: upload the photo to private storage
  /// (reporting progress), then attach the returned key to a verification.
  Future<void> uploadAndSubmit({
    required String type,
    required List<int> bytes,
    required String contentType,
    String? vehicleId,
  }) async {
    final current = state;
    final existing = current is VerificationsLoaded ? current.items : <Verification>[];
    emit(VerificationsLoaded(existing, submitting: true, uploadProgress: 0));
    try {
      final key = await _repo.uploadDocument(
        purpose: type,
        bytes: bytes,
        contentType: contentType,
        onProgress: (sent, total) {
          if (total > 0 && !isClosed) {
            emit(VerificationsLoaded(
              existing,
              submitting: true,
              uploadProgress: (sent / total).clamp(0, 1).toDouble(),
            ));
          }
        },
      );
      final v = await _repo.submit(type: type, docKey: key, vehicleId: vehicleId);
      emit(VerificationsLoaded([v, ...existing]));
    } on ApiException catch (e) {
      emit(VerificationsLoaded(existing, error: e.message));
    }
  }
}
