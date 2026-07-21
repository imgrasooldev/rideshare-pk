import '../../../core/network/api_client.dart';

class Earnings {
  const Earnings({
    required this.today,
    required this.thisMonth,
    required this.allTime,
    required this.tripsThisMonth,
    required this.activeSubscribers,
    required this.monthlyRecurring,
    required this.openRides,
    required this.commissionRate,
    required this.commissionThisMonth,
    required this.netThisMonth,
    required this.ratingAvg,
    required this.ratingCount,
  });

  factory Earnings.fromJson(Map<String, dynamic> j) => Earnings(
        today: (j['today'] as num?)?.toInt() ?? 0,
        thisMonth: (j['thisMonth'] as num?)?.toInt() ?? 0,
        allTime: (j['allTime'] as num?)?.toInt() ?? 0,
        tripsThisMonth: (j['tripsThisMonth'] as num?)?.toInt() ?? 0,
        activeSubscribers: (j['activeSubscribers'] as num?)?.toInt() ?? 0,
        monthlyRecurring: (j['monthlyRecurring'] as num?)?.toInt() ?? 0,
        openRides: (j['openRides'] as num?)?.toInt() ?? 0,
        commissionRate: (j['commissionRate'] as num?)?.toDouble() ?? 0,
        commissionThisMonth: (j['commissionThisMonth'] as num?)?.toInt() ?? 0,
        netThisMonth: (j['netThisMonth'] as num?)?.toInt() ?? 0,
        ratingAvg: (j['ratingAvg'] as num?)?.toDouble() ?? 0,
        ratingCount: (j['ratingCount'] as num?)?.toInt() ?? 0,
      );

  final int today;
  final int thisMonth;
  final int allTime;
  final int tripsThisMonth;
  final int activeSubscribers;
  final int monthlyRecurring;
  final int openRides;
  final double commissionRate;
  final int commissionThisMonth;
  final int netThisMonth;
  final double ratingAvg;
  final int ratingCount;
}

class EarningsRepository {
  EarningsRepository(this._api);
  final ApiClient _api;

  Future<Earnings> fetch() async => Earnings.fromJson(await _api.get('/earnings'));
}
