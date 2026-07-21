import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/messages_repository.dart';

sealed class ThreadsState extends Equatable {
  const ThreadsState();
  @override
  List<Object?> get props => [];
}

final class ThreadsLoading extends ThreadsState {
  const ThreadsLoading();
}

final class ThreadsLoaded extends ThreadsState {
  const ThreadsLoaded(this.threads);
  final List<ChatThread> threads;
  @override
  List<Object?> get props => [threads];
}

final class ThreadsFailed extends ThreadsState {
  const ThreadsFailed(this.message);
  final String message;
  @override
  List<Object?> get props => [message];
}

class ThreadsCubit extends Cubit<ThreadsState> {
  ThreadsCubit(this._repo) : super(const ThreadsLoading());
  final MessagesRepository _repo;

  Future<void> load() async {
    emit(const ThreadsLoading());
    try {
      emit(ThreadsLoaded(await _repo.threads()));
    } catch (_) {
      emit(const ThreadsFailed('Could not load your conversations'));
    }
  }
}
