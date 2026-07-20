import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/models/vehicle.dart';
import '../data/vehicles_repository.dart';

sealed class VehiclesState extends Equatable {
  const VehiclesState();
  @override
  List<Object?> get props => [];
}

final class VehiclesLoading extends VehiclesState {
  const VehiclesLoading();
}

final class VehiclesLoaded extends VehiclesState {
  const VehiclesLoaded(this.vehicles, {this.adding = false, this.error});
  final List<Vehicle> vehicles;
  final bool adding;
  final String? error;
  @override
  List<Object?> get props => [vehicles, adding, error];
}

final class VehiclesError extends VehiclesState {
  const VehiclesError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class VehiclesCubit extends Cubit<VehiclesState> {
  VehiclesCubit(this._repo) : super(const VehiclesLoading());

  final VehiclesRepository _repo;

  Future<void> load() async {
    emit(const VehiclesLoading());
    try {
      emit(VehiclesLoaded(await _repo.mine()));
    } on ApiException catch (e) {
      emit(VehiclesError(e.message));
    }
  }

  Future<void> add({
    required String make,
    required String model,
    required String plate,
    required int seats,
  }) async {
    final current = state;
    final existing = current is VehiclesLoaded ? current.vehicles : <Vehicle>[];
    emit(VehiclesLoaded(existing, adding: true));
    try {
      final vehicle = await _repo.create(make: make, model: model, plate: plate, seats: seats);
      emit(VehiclesLoaded([...existing, vehicle]));
    } on ApiException catch (e) {
      emit(VehiclesLoaded(existing, error: e.message));
    }
  }
}
