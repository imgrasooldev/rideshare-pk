import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/bookings_repository.dart';
import '../data/models/booking.dart';

sealed class MyBookingsEvent extends Equatable {
  const MyBookingsEvent();
  @override
  List<Object?> get props => [];
}

final class MyBookingsRequested extends MyBookingsEvent {
  const MyBookingsRequested();
}

final class BookingCancelPressed extends MyBookingsEvent {
  const BookingCancelPressed(this.bookingId);
  final String bookingId;
  @override
  List<Object?> get props => [bookingId];
}

/// Rider accepts/declines a driver's counter-offer.
final class BookingCounterResponded extends MyBookingsEvent {
  const BookingCounterResponded(this.bookingId, this.accept);
  final String bookingId;
  final bool accept;
  @override
  List<Object?> get props => [bookingId, accept];
}

sealed class MyBookingsState extends Equatable {
  const MyBookingsState();
  @override
  List<Object?> get props => [];
}

final class MyBookingsLoading extends MyBookingsState {
  const MyBookingsLoading();
}

final class MyBookingsLoaded extends MyBookingsState {
  const MyBookingsLoaded(this.bookings, {this.cancelling = const {}});
  final List<Booking> bookings;
  final Set<String> cancelling;
  @override
  List<Object?> get props => [bookings, cancelling];
}

final class MyBookingsError extends MyBookingsState {
  const MyBookingsError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class MyBookingsBloc extends Bloc<MyBookingsEvent, MyBookingsState> {
  MyBookingsBloc(this._repo) : super(const MyBookingsLoading()) {
    on<MyBookingsRequested>(_onRequested);
    on<BookingCancelPressed>(_onCancel);
    on<BookingCounterResponded>(_onCounterResponded);
  }

  final BookingsRepository _repo;

  Future<void> _onRequested(MyBookingsRequested event, Emitter<MyBookingsState> emit) async {
    emit(const MyBookingsLoading());
    try {
      final page = await _repo.mine();
      emit(MyBookingsLoaded(page.items));
    } on ApiException catch (e) {
      emit(MyBookingsError(e.message));
    }
  }

  Future<void> _onCancel(BookingCancelPressed event, Emitter<MyBookingsState> emit) async {
    final current = state;
    if (current is! MyBookingsLoaded) return;
    emit(MyBookingsLoaded(current.bookings, cancelling: {...current.cancelling, event.bookingId}));
    try {
      final cancelled = await _repo.cancel(event.bookingId);
      final updated = current.bookings
          .map((b) => b.id == cancelled.id
              ? Booking(
                  id: b.id,
                  rideId: b.rideId,
                  seats: b.seats,
                  status: 'cancelled',
                  createdAt: b.createdAt,
                  originLabel: b.originLabel,
                  destLabel: b.destLabel,
                  departAt: b.departAt,
                  pricePerSeat: b.pricePerSeat,
                )
              : b)
          .toList();
      emit(MyBookingsLoaded(updated));
    } on ApiException {
      emit(MyBookingsLoaded(current.bookings));
    }
  }

  Future<void> _onCounterResponded(
      BookingCounterResponded event, Emitter<MyBookingsState> emit) async {
    final current = state;
    if (current is! MyBookingsLoaded) return;
    emit(MyBookingsLoaded(current.bookings, cancelling: {...current.cancelling, event.bookingId}));
    try {
      await _repo.respondToCounter(event.bookingId, event.accept);
      final page = await _repo.mine(); // refresh statuses (confirmed/cancelled)
      emit(MyBookingsLoaded(page.items));
    } on ApiException {
      emit(MyBookingsLoaded(current.bookings));
    }
  }
}
