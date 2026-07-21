import '../../../core/network/api_client.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        type: json['type'] as String? ?? 'system',
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        read: json['readAt'] != null,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );

  final String id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;
}

class NotificationsPage {
  const NotificationsPage({required this.items, required this.unread});
  final List<AppNotification> items;
  final int unread;
}

class NotificationsRepository {
  NotificationsRepository(this._api);
  final ApiClient _api;

  Future<NotificationsPage> fetch() async {
    final res = await _api.get('/notifications', query: {'limit': 40});
    final items = (res['items'] as List<dynamic>? ?? [])
        .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
        .toList();
    return NotificationsPage(items: items, unread: (res['unread'] as num?)?.toInt() ?? 0);
  }

  Future<void> markAllRead() => _api.post('/notifications/read-all');

  Future<void> markRead(String id) => _api.post('/notifications/$id/read');
}
