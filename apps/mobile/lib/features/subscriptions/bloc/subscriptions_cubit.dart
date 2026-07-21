import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/subscriptions_repository.dart';

sealed class SubscriptionsState extends Equatable {
  const SubscriptionsState();
  @override
  List<Object?> get props => [];
}

final class SubscriptionsLoading extends SubscriptionsState {
  const SubscriptionsLoading();
}

final class SubscriptionsLoaded extends SubscriptionsState {
  const SubscriptionsLoaded(this.items, {this.busyId});
  final List<Subscription> items;
  final String? busyId;
  @override
  List<Object?> get props => [items, busyId];
}

final class SubscriptionsError extends SubscriptionsState {
  const SubscriptionsError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class SubscriptionsCubit extends Cubit<SubscriptionsState> {
  SubscriptionsCubit(this._repo) : super(const SubscriptionsLoading());
  final SubscriptionsRepository _repo;

  Future<void> load() async {
    emit(const SubscriptionsLoading());
    try {
      emit(SubscriptionsLoaded(await _repo.mine()));
    } catch (e) {
      emit(SubscriptionsError(e.toString()));
    }
  }

  Future<void> cancel(String id) async {
    final s = state;
    if (s is! SubscriptionsLoaded) return;
    emit(SubscriptionsLoaded(s.items, busyId: id));
    try {
      await _repo.cancel(id);
    } catch (_) {
      /* ignore, refresh below */
    }
    await load();
  }
}
