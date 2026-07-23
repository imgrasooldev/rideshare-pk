import '../../../core/network/api_client.dart';

/// Someone the user has chosen never to be matched with again.
class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.createdAt,
    this.name,
    this.reason,
  });

  factory BlockedUser.fromJson(Map<String, dynamic> json) => BlockedUser(
        userId: json['userId'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        name: json['name'] as String?,
        reason: json['reason'] as String?,
      );

  final String userId;
  final DateTime createdAt;
  final String? name;
  final String? reason;

  String get label => name ?? 'User ${userId.substring(0, 8)}';
}

class BlocksRepository {
  BlocksRepository(this._api);
  final ApiClient _api;

  Future<List<BlockedUser>> mine() async {
    final list = await _api.getList('/blocks');
    return list.map((e) => BlockedUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> block(String userId, {String? reason}) =>
      _api.post('/blocks/$userId', body: {'reason': ?reason});

  Future<void> unblock(String userId) => _api.delete('/blocks/$userId');
}
