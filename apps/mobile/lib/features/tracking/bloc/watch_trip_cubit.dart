import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models/trip.dart';
import '../data/tracking_repository.dart';

sealed class WatchTripState extends Equatable {
  const WatchTripState();
  @override
  List<Object?> get props => [];
}

final class WatchConnecting extends WatchTripState {
  const WatchConnecting();
}

final class WatchLive extends WatchTripState {
  const WatchLive({this.location, this.shareToken});
  final LivePoint? location;
  final String? shareToken;

  WatchLive copyWith({LivePoint? location, String? shareToken}) =>
      WatchLive(location: location ?? this.location, shareToken: shareToken ?? this.shareToken);

  @override
  List<Object?> get props => [location, shareToken];
}

final class WatchEnded extends WatchTripState {
  const WatchEnded();
}

final class WatchError extends WatchTripState {
  const WatchError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

/// Rider/family side: subscribes to the trip's WS channel and mirrors events.
class WatchTripCubit extends Cubit<WatchTripState> {
  WatchTripCubit(this._repo) : super(const WatchConnecting());

  final TrackingRepository _repo;
  StreamSubscription<TrackingEvent>? _sub;

  Future<void> watch(String rideId) async {
    emit(const WatchConnecting());
    try {
      // Seed with the current snapshot (trip meta incl. share token).
      final snapshot = await _repo.currentLocation(rideId);
      emit(WatchLive(location: snapshot.location, shareToken: snapshot.trip?.shareToken));
    } catch (_) {
      emit(const WatchLive());
    }
    _sub = _repo.watch(rideId).listen((event) {
      final current = state;
      switch (event) {
        case TrackingLocation(:final point):
          emit(current is WatchLive ? current.copyWith(location: point) : WatchLive(location: point));
        case TrackingEnded():
          emit(const WatchEnded());
        case TrackingError(:final message):
          if (current is! WatchLive || current.location == null) {
            emit(WatchError(message));
          }
      }
    });
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
