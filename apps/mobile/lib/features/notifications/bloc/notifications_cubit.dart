import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/notifications_repository.dart';

class NotificationsState extends Equatable {
  const NotificationsState({
    this.items = const [],
    this.unread = 0,
    this.loading = false,
    this.loaded = false,
  });

  final List<AppNotification> items;
  final int unread;
  final bool loading;
  final bool loaded;

  NotificationsState copyWith({
    List<AppNotification>? items,
    int? unread,
    bool? loading,
    bool? loaded,
  }) =>
      NotificationsState(
        items: items ?? this.items,
        unread: unread ?? this.unread,
        loading: loading ?? this.loading,
        loaded: loaded ?? this.loaded,
      );

  @override
  List<Object?> get props => [items, unread, loading, loaded];
}

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this._repo) : super(const NotificationsState());
  final NotificationsRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(loading: true));
    try {
      final page = await _repo.fetch();
      emit(NotificationsState(
        items: page.items,
        unread: page.unread,
        loading: false,
        loaded: true,
      ));
    } catch (_) {
      emit(state.copyWith(loading: false, loaded: true));
    }
  }

  Future<void> markAllRead() async {
    if (state.unread == 0) return;
    emit(state.copyWith(
      unread: 0,
      items: state.items
          .map((n) => AppNotification(
                id: n.id,
                type: n.type,
                title: n.title,
                body: n.body,
                read: true,
                createdAt: n.createdAt,
              ))
          .toList(),
    ));
    try {
      await _repo.markAllRead();
    } catch (_) {
      /* optimistic — refetch on next load */
    }
  }
}
