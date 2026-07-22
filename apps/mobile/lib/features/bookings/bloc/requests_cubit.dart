import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/bookings_repository.dart';
import '../data/models/seat_request.dart';

sealed class RequestsState extends Equatable {
  const RequestsState();
  @override
  List<Object?> get props => [];
}

final class RequestsLoading extends RequestsState {
  const RequestsLoading();
}

final class RequestsLoaded extends RequestsState {
  const RequestsLoaded(this.requests, {this.busyId});
  final List<SeatRequest> requests;
  final String? busyId; // a request currently being acted on
  @override
  List<Object?> get props => [requests, busyId];
}

final class RequestsFailed extends RequestsState {
  const RequestsFailed();
}

class RequestsCubit extends Cubit<RequestsState> {
  RequestsCubit(this._repo) : super(const RequestsLoading());
  final BookingsRepository _repo;

  Future<void> load() async {
    emit(const RequestsLoading());
    try {
      emit(RequestsLoaded(await _repo.requests()));
    } catch (_) {
      emit(const RequestsFailed());
    }
  }

  Future<String?> _act(String id, Future<void> Function() action) async {
    final cur = state;
    if (cur is RequestsLoaded) emit(RequestsLoaded(cur.requests, busyId: id));
    try {
      await action();
      await load();
      return null;
    } catch (e) {
      await load();
      return 'Could not complete — the request may have changed';
    }
  }

  Future<String?> accept(String id) => _act(id, () => _repo.accept(id));
  Future<String?> reject(String id) => _act(id, () => _repo.reject(id));
  Future<String?> counter(String id, int price) => _act(id, () => _repo.counter(id, price));
}
