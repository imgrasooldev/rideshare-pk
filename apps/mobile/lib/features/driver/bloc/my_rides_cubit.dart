import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../rides/data/models/ride.dart';
import '../../rides/data/rides_repository.dart';

sealed class MyRidesState extends Equatable {
  const MyRidesState();
  @override
  List<Object?> get props => [];
}

final class MyRidesLoading extends MyRidesState {
  const MyRidesLoading();
}

final class MyRidesLoaded extends MyRidesState {
  const MyRidesLoaded(this.rides);
  final List<Ride> rides;
  @override
  List<Object?> get props => [rides];
}

final class MyRidesError extends MyRidesState {
  const MyRidesError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class MyRidesCubit extends Cubit<MyRidesState> {
  MyRidesCubit(this._repo) : super(const MyRidesLoading());

  final RidesRepository _repo;

  Future<void> load() async {
    emit(const MyRidesLoading());
    try {
      final page = await _repo.myRides();
      emit(MyRidesLoaded(page.items));
    } on ApiException catch (e) {
      emit(MyRidesError(e.message));
    }
  }
}
