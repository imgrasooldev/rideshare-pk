import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/bookings_repository.dart';
import '../data/models/booking.dart';

sealed class BookingActionState extends Equatable {
  const BookingActionState();
  @override
  List<Object?> get props => [];
}

final class BookingIdle extends BookingActionState {
  const BookingIdle();
}

final class BookingInFlight extends BookingActionState {
  const BookingInFlight(this.rideId);
  final String rideId;
  @override
  List<Object?> get props => [rideId];
}

final class BookingSuccess extends BookingActionState {
  const BookingSuccess(this.booking);
  final Booking booking;
  @override
  List<Object?> get props => [booking];
}

final class BookingFailure extends BookingActionState {
  const BookingFailure(this.rideId, this.message);
  final String rideId;
  final String message;
  @override
  List<Object?> get props => [rideId, message];
}

/// One booking attempt at a time. The idempotency key is fixed per attempt:
/// a network retry of the same attempt cannot double-book.
class BookingActionCubit extends Cubit<BookingActionState> {
  BookingActionCubit(this._repo) : super(const BookingIdle());

  final BookingsRepository _repo;

  Future<void> book(String rideId, int seats) async {
    if (state is BookingInFlight) return;
    emit(BookingInFlight(rideId));
    final key = _repo.newIdempotencyKey();
    try {
      final booking = await _repo.book(rideId: rideId, seats: seats, idempotencyKey: key);
      emit(BookingSuccess(booking));
    } on ApiException catch (e) {
      emit(BookingFailure(rideId, e.message));
    }
  }

  void reset() => emit(const BookingIdle());
}
