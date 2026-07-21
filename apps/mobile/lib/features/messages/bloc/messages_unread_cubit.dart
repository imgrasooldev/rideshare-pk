import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/messages_repository.dart';

/// Tracks the unread message count for the dashboard chat badge.
class MessagesUnreadCubit extends Cubit<int> {
  MessagesUnreadCubit(this._repo) : super(0);
  final MessagesRepository _repo;

  Future<void> load() async {
    try {
      emit(await _repo.unreadCount());
    } catch (_) {
      /* keep last known count */
    }
  }
}
