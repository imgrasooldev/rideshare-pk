import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/location_source.dart';
import '../data/models/trip.dart';
import '../data/tracking_repository.dart';

sealed class DriverTripState extends Equatable {
  const DriverTripState();
  @override
  List<Object?> get props => [];
}

final class DriverTripIdle extends DriverTripState {
  const DriverTripIdle();
}

final class DriverTripStarting extends DriverTripState {
  const DriverTripStarting();
}

final class DriverTripLive extends DriverTripState {
  const DriverTripLive({
    required this.trip,
    this.lastSent,
    this.demoMode = false,
  });

  final Trip trip;
  final LivePoint? lastSent;
  final bool demoMode;

  DriverTripLive copyWith({LivePoint? lastSent, bool? demoMode}) =>
      DriverTripLive(trip: trip, lastSent: lastSent ?? this.lastSent, demoMode: demoMode ?? this.demoMode);

  @override
  List<Object?> get props => [trip, lastSent, demoMode];
}

final class DriverTripEnded extends DriverTripState {
  const DriverTripEnded();
}

final class DriverTripError extends DriverTripState {
  const DriverTripError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

/// Driver side: starts the trip, then pings the current position every
/// [pingInterval]. GPS by default; falls back to the demo route source when
/// GPS is unavailable so the flow always works.
class DriverTripCubit extends Cubit<DriverTripState> {
  DriverTripCubit(
    this._repo, {
    required this.gps,
    required this.fallback,
    this.pingInterval = const Duration(seconds: 4),
  }) : super(const DriverTripIdle());

  final TrackingRepository _repo;
  final LocationSource gps;
  final LocationSource fallback;
  final Duration pingInterval;

  Timer? _timer;
  String? _rideId;
  bool _usingFallback = false;

  Future<void> start(String rideId) async {
    if (state is DriverTripStarting || state is DriverTripLive) return;
    emit(const DriverTripStarting());
    try {
      _rideId = rideId;
      final trip = await _repo.startTrip(rideId);
      emit(DriverTripLive(trip: trip));
      _timer = Timer.periodic(pingInterval, (_) => tick());
      await tick(); // first position immediately
    } on ApiException catch (e) {
      emit(DriverTripError(e.message));
    }
  }

  /// One ping cycle — public so tests can drive it without real timers.
  Future<void> tick() async {
    final current = state;
    final rideId = _rideId;
    if (current is! DriverTripLive || rideId == null) return;

    var position = _usingFallback ? await fallback.next() : await gps.next();
    if (position == null && !_usingFallback) {
      _usingFallback = true;
      position = await fallback.next();
    }
    if (position == null) return;

    try {
      await _repo.pingLocation(rideId, position.lat, position.lng);
      emit(current.copyWith(
        lastSent: LivePoint(lat: position.lat, lng: position.lng, at: DateTime.now()),
        demoMode: _usingFallback,
      ));
    } on ApiException {
      // Transient ping failures are non-fatal; next tick retries.
    }
  }

  Future<void> end() async {
    final rideId = _rideId;
    if (rideId == null) return;
    _timer?.cancel();
    try {
      await _repo.endTrip(rideId);
      emit(const DriverTripEnded());
    } on ApiException catch (e) {
      emit(DriverTripError(e.message));
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
