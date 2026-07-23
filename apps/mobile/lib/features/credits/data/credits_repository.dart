import '../../../core/network/api_client.dart';

class CreditEntry {
  const CreditEntry({
    required this.id,
    required this.amountPaisa,
    required this.kind,
    this.description,
    required this.createdAt,
  });

  factory CreditEntry.fromJson(Map<String, dynamic> j) => CreditEntry(
        id: j['id'] as String,
        amountPaisa: (j['amountPaisa'] as num).toInt(),
        kind: j['kind'] as String,
        description: j['description'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      );

  final String id;
  final int amountPaisa;
  final String kind;
  final String? description;
  final DateTime createdAt;

  double get amountRupees => amountPaisa / 100;
}

class CreditSummary {
  const CreditSummary({required this.balanceRupees, required this.entries});

  factory CreditSummary.fromJson(Map<String, dynamic> j) => CreditSummary(
        balanceRupees: (j['balanceRupees'] as num).toDouble(),
        entries: ((j['entries'] as List?) ?? const [])
            .map((e) => CreditEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final double balanceRupees;
  final List<CreditEntry> entries;
}

class CreditsRepository {
  CreditsRepository(this._api);

  final ApiClient _api;

  Future<CreditSummary> summary() async {
    final json = await _api.get('/credits');
    return CreditSummary.fromJson(json);
  }

  /// Converts earned referral signups into wallet credit (idempotent server-side).
  /// Returns how many new referrals were credited.
  Future<int> redeemReferrals() async {
    final json = await _api.post('/credits/redeem-referrals');
    return (json['credited'] as num?)?.toInt() ?? 0;
  }
}
