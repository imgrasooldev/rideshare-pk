import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/messages_repository.dart';

class ChatState extends Equatable {
  const ChatState({
    this.messages = const [],
    this.loading = true,
    this.sending = false,
    this.error,
  });

  final List<Message> messages;
  final bool loading;
  final bool sending;
  final String? error;

  ChatState copyWith({
    List<Message>? messages,
    bool? loading,
    bool? sending,
    String? error,
    bool clearError = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        loading: loading ?? this.loading,
        sending: sending ?? this.sending,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [messages, loading, sending, error];
}

/// A single ride↔user conversation. Polls for new messages every few seconds
/// while the chat screen is open.
class ChatCubit extends Cubit<ChatState> {
  ChatCubit(this._repo, {required this.rideId, required this.otherId})
      : super(const ChatState());

  final MessagesRepository _repo;
  final String rideId;
  final String otherId;
  Timer? _poll;

  Future<void> load() async {
    try {
      final msgs = await _repo.thread(rideId, otherId);
      emit(state.copyWith(messages: msgs, loading: false, clearError: true));
    } catch (_) {
      emit(state.copyWith(loading: false, error: 'Could not load messages'));
    }
    _poll ??= Timer.periodic(const Duration(seconds: 4), (_) => _refresh());
  }

  Future<void> _refresh() async {
    try {
      final msgs = await _repo.thread(rideId, otherId);
      if (!isClosed) emit(state.copyWith(messages: msgs));
    } catch (_) {
      /* transient; keep showing what we have */
    }
  }

  Future<void> send(String recipientId, String body) async {
    final clean = body.trim();
    if (clean.isEmpty || state.sending) return;
    emit(state.copyWith(sending: true));
    try {
      await _repo.send(rideId: rideId, recipientId: recipientId, body: clean);
      final msgs = await _repo.thread(rideId, otherId);
      emit(state.copyWith(messages: msgs, sending: false, clearError: true));
    } catch (_) {
      emit(state.copyWith(sending: false, error: 'Message failed to send'));
    }
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}
