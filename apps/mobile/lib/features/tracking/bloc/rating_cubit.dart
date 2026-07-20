import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/tracking_repository.dart';

sealed class RatingState extends Equatable {
  const RatingState();
  @override
  List<Object?> get props => [];
}

final class RatingIdle extends RatingState {
  const RatingIdle();
}

final class RatingSubmitting extends RatingState {
  const RatingSubmitting();
}

final class RatingDone extends RatingState {
  const RatingDone();
}

final class RatingFailed extends RatingState {
  const RatingFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class RatingCubit extends Cubit<RatingState> {
  RatingCubit(this._repo) : super(const RatingIdle());

  final TrackingRepository _repo;

  Future<void> rate({
    required String rideId,
    required String toUserId,
    required int stars,
    String? comment,
  }) async {
    if (state is RatingSubmitting) return;
    emit(const RatingSubmitting());
    try {
      await _repo.rate(rideId: rideId, toUserId: toUserId, stars: stars, comment: comment);
      emit(const RatingDone());
    } on ApiException catch (e) {
      // Already rated is a success from the user's perspective.
      if (e.statusCode == 409) {
        emit(const RatingDone());
      } else {
        emit(RatingFailed(e.message));
      }
    }
  }
}
