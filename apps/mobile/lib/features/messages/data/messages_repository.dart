import '../../../core/network/api_client.dart';

/// A single chat message about a ride.
class Message {
  const Message({
    required this.id,
    required this.rideId,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  factory Message.fromJson(Map<String, dynamic> j) => Message(
        id: j['id'] as String? ?? '',
        rideId: j['rideId'] as String? ?? '',
        senderId: j['senderId'] as String? ?? '',
        recipientId: j['recipientId'] as String? ?? '',
        body: j['body'] as String? ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        readAt: (j['readAt'] as String?) != null
            ? DateTime.tryParse(j['readAt'] as String)?.toLocal()
            : null,
      );

  final String id;
  final String rideId;
  final String senderId;
  final String recipientId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  bool sentBy(String userId) => senderId == userId;
}

/// One conversation summary for the inbox.
class ChatThread {
  const ChatThread({
    required this.rideId,
    required this.otherId,
    required this.otherName,
    required this.originLabel,
    required this.destLabel,
    required this.lastBody,
    required this.lastAt,
    required this.lastFromMe,
    required this.unread,
  });

  factory ChatThread.fromJson(Map<String, dynamic> j) => ChatThread(
        rideId: j['rideId'] as String? ?? '',
        otherId: j['otherId'] as String? ?? '',
        otherName: j['otherName'] as String?,
        originLabel: j['originLabel'] as String? ?? '',
        destLabel: j['destLabel'] as String? ?? '',
        lastBody: j['lastBody'] as String? ?? '',
        lastAt: DateTime.tryParse(j['lastAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        lastFromMe: j['lastFromMe'] as bool? ?? false,
        unread: (j['unread'] as num?)?.toInt() ?? 0,
      );

  final String rideId;
  final String otherId;
  final String? otherName;
  final String originLabel;
  final String destLabel;
  final String lastBody;
  final DateTime lastAt;
  final bool lastFromMe;
  final int unread;
}

class MessagesRepository {
  MessagesRepository(this._api);
  final ApiClient _api;

  Future<List<ChatThread>> threads() async {
    final res = await _api.getList('/messages/threads');
    return res.cast<Map<String, dynamic>>().map(ChatThread.fromJson).toList();
  }

  Future<List<Message>> thread(String rideId, String otherId, {int limit = 100}) async {
    final res = await _api.getList('/messages/thread', query: {
      'rideId': rideId,
      'otherId': otherId,
      'limit': limit,
    });
    return res.cast<Map<String, dynamic>>().map(Message.fromJson).toList();
  }

  Future<Message> send({
    required String rideId,
    required String recipientId,
    required String body,
  }) async {
    final res = await _api.post('/messages', body: {
      'rideId': rideId,
      'recipientId': recipientId,
      'body': body,
    });
    return Message.fromJson(res);
  }

  Future<int> unreadCount() async {
    final res = await _api.get('/messages/unread-count');
    return (res['count'] as num?)?.toInt() ?? 0;
  }
}
