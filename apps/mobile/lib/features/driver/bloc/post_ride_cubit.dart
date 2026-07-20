import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../rides/data/models/ride.dart';
import '../../rides/data/rides_repository.dart';

sealed class PostRideState extends Equatable {
  const PostRideState();
  @override
  List<Object?> get props => [];
}

final class PostRideIdle extends PostRideState {
  const PostRideIdle();
}

final class PostRideSubmitting extends PostRideState {
  const PostRideSubmitting();
}

final class PostRideSuccess extends PostRideState {
  const PostRideSuccess(this.ride);
  final Ride ride;
  @override
  List<Object?> get props => [ride];
}

final class PostRideFailure extends PostRideState {
  const PostRideFailure(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class PostRideCubit extends Cubit<PostRideState> {
  PostRideCubit(this._repo) : super(const PostRideIdle());

  final RidesRepository _repo;

  Future<void> submit({
    required Hub origin,
    required Hub dest,
    required DateTime departAt,
    required List<int> recurringDays,
    required int seatsTotal,
    required int pricePerSeat,
    String vehicleType = 'car',
    bool ladiesOnly = false,
  }) async {
    if (state is PostRideSubmitting) return;
    emit(const PostRideSubmitting());
    try {
      final ride = await _repo.postRide(
        origin: origin,
        dest: dest,
        departAt: departAt,
        recurringDays: recurringDays,
        seatsTotal: seatsTotal,
        pricePerSeat: pricePerSeat,
        vehicleType: vehicleType,
        ladiesOnly: ladiesOnly,
      );
      emit(PostRideSuccess(ride));
    } on ApiException catch (e) {
      emit(PostRideFailure(e.message));
    }
  }

  void reset() => emit(const PostRideIdle());
}
