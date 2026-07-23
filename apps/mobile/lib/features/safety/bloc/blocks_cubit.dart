import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../data/blocks_repository.dart';

sealed class BlocksState extends Equatable {
  const BlocksState();
  @override
  List<Object?> get props => [];
}

final class BlocksLoading extends BlocksState {
  const BlocksLoading();
}

final class BlocksLoaded extends BlocksState {
  const BlocksLoaded(this.people, {this.busyIds = const {}});
  final List<BlockedUser> people;
  final Set<String> busyIds;
  @override
  List<Object?> get props => [people, busyIds];
}

final class BlocksError extends BlocksState {
  const BlocksError(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class BlocksCubit extends Cubit<BlocksState> {
  BlocksCubit(this._repo) : super(const BlocksLoading());

  final BlocksRepository _repo;

  Future<void> load() async {
    emit(const BlocksLoading());
    try {
      emit(BlocksLoaded(await _repo.mine()));
    } on ApiException catch (e) {
      emit(BlocksError(e.message));
    }
  }

  /// Blocking from a ride/trip screen — the list is refreshed lazily, since
  /// the user is usually not looking at it when they block someone.
  Future<bool> block(String userId, {String? reason}) async {
    try {
      await _repo.block(userId, reason: reason);
      if (state is BlocksLoaded) await load();
      return true;
    } on ApiException {
      return false;
    }
  }

  Future<void> unblock(String userId) async {
    final current = state;
    if (current is! BlocksLoaded) return;
    emit(BlocksLoaded(current.people, busyIds: {...current.busyIds, userId}));
    try {
      await _repo.unblock(userId);
      emit(BlocksLoaded(current.people.where((p) => p.userId != userId).toList()));
    } on ApiException {
      emit(BlocksLoaded(current.people));
    }
  }
}
