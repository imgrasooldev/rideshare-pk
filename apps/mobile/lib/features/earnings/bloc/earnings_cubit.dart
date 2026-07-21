import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/earnings_repository.dart';

sealed class EarningsState extends Equatable {
  const EarningsState();
  @override
  List<Object?> get props => [];
}

final class EarningsLoading extends EarningsState {
  const EarningsLoading();
}

final class EarningsLoaded extends EarningsState {
  const EarningsLoaded(this.data);
  final Earnings data;
  @override
  List<Object?> get props => [data];
}

final class EarningsFailed extends EarningsState {
  const EarningsFailed();
}

class EarningsCubit extends Cubit<EarningsState> {
  EarningsCubit(this._repo) : super(const EarningsLoading());
  final EarningsRepository _repo;

  Future<void> load() async {
    emit(const EarningsLoading());
    try {
      emit(EarningsLoaded(await _repo.fetch()));
    } catch (_) {
      emit(const EarningsFailed());
    }
  }
}
