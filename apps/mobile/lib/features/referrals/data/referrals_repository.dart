import '../../../core/network/api_client.dart';

class ReferralSummary {
  const ReferralSummary({required this.code, required this.count, this.referredBy});
  factory ReferralSummary.fromJson(Map<String, dynamic> j) => ReferralSummary(
        code: j['code'] as String? ?? '',
        count: (j['count'] as num?)?.toInt() ?? 0,
        referredBy: j['referredBy'] as String?,
      );
  final String code;
  final int count;
  final String? referredBy;
}

class ReferralsRepository {
  ReferralsRepository(this._api);
  final ApiClient _api;

  Future<ReferralSummary> me() async =>
      ReferralSummary.fromJson(await _api.get('/referrals/me'));

  Future<void> apply(String code) => _api.post('/referrals/apply', body: {'code': code});
}
