import '../../../core/network/api_client.dart';

class Subscription {
  const Subscription({
    required this.id,
    required this.rideId,
    required this.seats,
    required this.pricePerMonth,
    required this.status,
    required this.renewsOn,
    this.originLabel,
    this.destLabel,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final ride = json['ride'] as Map<String, dynamic>?;
    return Subscription(
      id: json['id'] as String,
      rideId: json['rideId'] as String,
      seats: json['seats'] as int? ?? 1,
      pricePerMonth: json['pricePerMonth'] as int? ?? 0,
      status: json['status'] as String? ?? 'active',
      renewsOn: DateTime.tryParse(json['renewsOn'] as String? ?? '') ?? DateTime.now(),
      originLabel: ride?['originLabel'] as String?,
      destLabel: ride?['destLabel'] as String?,
    );
  }

  final String id;
  final String rideId;
  final int seats;
  final int pricePerMonth;
  final String status;
  final DateTime renewsOn;
  final String? originLabel;
  final String? destLabel;

  bool get isActive => status == 'active';
}

class SubscriptionsRepository {
  SubscriptionsRepository(this._api);
  final ApiClient _api;

  Future<Subscription> subscribe(String rideId, {int seats = 1}) async =>
      Subscription.fromJson(await _api.post('/subscriptions', body: {'rideId': rideId, 'seats': seats}));

  Future<List<Subscription>> mine() async {
    final list = await _api.getList('/subscriptions/mine');
    return list.map((e) => Subscription.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Subscription> cancel(String id) async =>
      Subscription.fromJson(await _api.post('/subscriptions/$id/cancel'));
}
