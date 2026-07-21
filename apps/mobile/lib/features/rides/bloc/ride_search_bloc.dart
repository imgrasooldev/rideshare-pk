import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/models/ride.dart';
import '../data/rides_repository.dart';

// ---------- Events ----------

sealed class RideSearchEvent extends Equatable {
  const RideSearchEvent();
  @override
  List<Object?> get props => [];
}

final class RideSearchSubmitted extends RideSearchEvent {
  const RideSearchSubmitted({
    required this.pickup,
    required this.drop,
    required this.day,
    this.ladiesOnly = false,
    this.vehicleType,
    this.vertical,
  });

  final Hub pickup;
  final Hub drop;
  final DateTime day;
  final bool ladiesOnly;
  /// null = any vehicle type.
  final String? vehicleType;
  /// null = any category; otherwise a ride `vertical` (e.g. 'office', 'city').
  final String? vertical;

  @override
  List<Object?> get props =>
      [pickup.label, drop.label, day, ladiesOnly, vehicleType, vertical];
}

final class RideSearchNextPageRequested extends RideSearchEvent {
  const RideSearchNextPageRequested();
}

// ---------- States ----------

sealed class RideSearchState extends Equatable {
  const RideSearchState();
  @override
  List<Object?> get props => [];
}

final class RideSearchInitial extends RideSearchState {
  const RideSearchInitial();
}

final class RideSearchLoading extends RideSearchState {
  const RideSearchLoading();
}

final class RideSearchLoaded extends RideSearchState {
  const RideSearchLoaded({
    required this.rides,
    required this.query,
    this.nextCursor,
    this.loadingMore = false,
  });

  final List<Ride> rides;
  final RideSearchSubmitted query;
  final String? nextCursor;
  final bool loadingMore;

  bool get hasMore => nextCursor != null;

  RideSearchLoaded copyWith({List<Ride>? rides, String? nextCursor, bool? loadingMore}) =>
      RideSearchLoaded(
        rides: rides ?? this.rides,
        query: query,
        nextCursor: nextCursor,
        loadingMore: loadingMore ?? this.loadingMore,
      );

  @override
  List<Object?> get props => [rides, query, nextCursor, loadingMore];
}

final class RideSearchError extends RideSearchState {
  const RideSearchError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

// ---------- Bloc ----------

class RideSearchBloc extends Bloc<RideSearchEvent, RideSearchState> {
  RideSearchBloc(this._repo) : super(const RideSearchInitial()) {
    on<RideSearchSubmitted>(_onSubmitted);
    on<RideSearchNextPageRequested>(_onNextPage);
  }

  final RidesRepository _repo;

  (DateTime, DateTime) _window(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return (start, start.add(const Duration(days: 1)));
  }

  Future<void> _onSubmitted(RideSearchSubmitted event, Emitter<RideSearchState> emit) async {
    emit(const RideSearchLoading());
    try {
      final (after, before) = _window(event.day);
      final page = await _repo.search(
        pickup: event.pickup,
        drop: event.drop,
        departAfter: after,
        departBefore: before,
        ladiesOnly: event.ladiesOnly ? true : null,
        vehicleType: event.vehicleType,
        vertical: event.vertical,
      );
      emit(RideSearchLoaded(rides: page.items, query: event, nextCursor: page.nextCursor));
    } on ApiException catch (e) {
      emit(RideSearchError(e.message));
    }
  }

  Future<void> _onNextPage(RideSearchNextPageRequested event, Emitter<RideSearchState> emit) async {
    final current = state;
    if (current is! RideSearchLoaded || !current.hasMore || current.loadingMore) return;
    emit(current.copyWith(loadingMore: true));
    try {
      final (after, before) = _window(current.query.day);
      final page = await _repo.search(
        pickup: current.query.pickup,
        drop: current.query.drop,
        departAfter: after,
        departBefore: before,
        ladiesOnly: current.query.ladiesOnly ? true : null,
        vehicleType: current.query.vehicleType,
        vertical: current.query.vertical,
        cursor: current.nextCursor,
      );
      emit(current.copyWith(
        rides: [...current.rides, ...page.items],
        nextCursor: page.nextCursor,
        loadingMore: false,
      ));
    } on ApiException {
      emit(current.copyWith(loadingMore: false));
    }
  }
}
