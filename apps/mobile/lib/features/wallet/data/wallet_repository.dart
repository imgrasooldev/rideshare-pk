import '../../../core/network/api_client.dart';

/// Driver wallet: cash fares collected, the platform's commission share, and
/// what's been settled back.
class Wallet {
  const Wallet({
    required this.commissionRate,
    required this.grossFares,
    required this.commissionAccrued,
    required this.settledTotal,
    required this.commissionOwed,
    required this.cashKept,
  });

  factory Wallet.fromJson(Map<String, dynamic> j) => Wallet(
        commissionRate: (j['commissionRate'] as num?)?.toDouble() ?? 0.1,
        grossFares: (j['grossFares'] as num?)?.toInt() ?? 0,
        commissionAccrued: (j['commissionAccrued'] as num?)?.toInt() ?? 0,
        settledTotal: (j['settledTotal'] as num?)?.toInt() ?? 0,
        commissionOwed: (j['commissionOwed'] as num?)?.toInt() ?? 0,
        cashKept: (j['cashKept'] as num?)?.toInt() ?? 0,
      );

  final double commissionRate;
  final int grossFares;
  final int commissionAccrued;
  final int settledTotal;
  final int commissionOwed;
  final int cashKept;
}

class Settlement {
  const Settlement({
    required this.id,
    required this.amount,
    required this.method,
    required this.createdAt,
    this.reference,
  });

  factory Settlement.fromJson(Map<String, dynamic> j) => Settlement(
        id: j['id'] as String? ?? '',
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        method: j['method'] as String? ?? 'cash_deposit',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        reference: j['reference'] as String?,
      );

  final String id;
  final int amount;
  final String method;
  final DateTime createdAt;
  final String? reference;
}

class WalletRepository {
  WalletRepository(this._api);
  final ApiClient _api;

  Future<Wallet> fetch() async => Wallet.fromJson(await _api.get('/wallet'));

  Future<List<Settlement>> history() async {
    final res = await _api.getList('/wallet/history');
    return res.cast<Map<String, dynamic>>().map(Settlement.fromJson).toList();
  }

  Future<Settlement> settle(int amount, {String? reference}) async => Settlement.fromJson(
        await _api.post('/wallet/settle', body: {
          'amount': amount,
          if (reference != null && reference.isNotEmpty) 'reference': reference,
        }),
      );
}
