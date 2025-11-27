import 'dart:convert';

/// Core models for the OMK in-app wallet.
///
/// These are intentionally lightweight data classes with simple
/// JSON helpers so they can be cached in SharedPreferences or
/// any other local store.

class OmkWalletBalance {
  OmkWalletBalance({
    required this.balanceOmk,
    required this.lastUpdated,
  });

  final String balanceOmk; // decimal string, e.g. "123.45"
  final DateTime lastUpdated;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'balanceOmk': balanceOmk,
        'lastUpdated': lastUpdated.toIso8601String(),
      };

  factory OmkWalletBalance.fromJson(Map<String, dynamic> json) {
    final ts = json['lastUpdated'] as String?;
    return OmkWalletBalance(
      balanceOmk: (json['balanceOmk'] as String?) ?? '0',
      lastUpdated: ts != null
          ? DateTime.tryParse(ts) ?? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static OmkWalletBalance zero() => OmkWalletBalance(
        balanceOmk: '0',
        lastUpdated: DateTime.fromMillisecondsSinceEpoch(0),
      );
}

class WalletTransaction {
  WalletTransaction({
    required this.id,
    required this.type,
    required this.amountOmk,
    required this.timestamp,
    this.description,
  });

  final String id;
  final String type; // 'topup' | 'llm_spend' | 'reward' | future types
  final String amountOmk; // decimal string
  final DateTime timestamp;
  final String? description;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'type': type,
        'amountOmk': amountOmk,
        'timestamp': timestamp.toIso8601String(),
        'description': description,
      };

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    final ts = json['timestamp'] as String?;
    return WalletTransaction(
      id: (json['id'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'llm_spend',
      amountOmk: (json['amountOmk'] as String?) ?? '0',
      timestamp: ts != null
          ? DateTime.tryParse(ts) ?? DateTime.fromMillisecondsSinceEpoch(0)
          : DateTime.fromMillisecondsSinceEpoch(0),
      description: json['description'] as String?,
    );
  }
}

String encodeWalletBalance(OmkWalletBalance balance) =>
    jsonEncode(balance.toJson());

OmkWalletBalance? decodeWalletBalance(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final map = jsonDecode(raw);
    if (map is Map<String, dynamic>) {
      return OmkWalletBalance.fromJson(map);
    }
  } catch (_) {}
  return null;
}

String encodeWalletTransactions(List<WalletTransaction> txs) => jsonEncode(
      txs.map((t) => t.toJson()).toList(growable: false),
    );

List<WalletTransaction> decodeWalletTransactions(String? raw) {
  if (raw == null || raw.isEmpty) return <WalletTransaction>[];
  try {
    final data = jsonDecode(raw);
    if (data is List) {
      return data
          .whereType<Map>()
          .map((m) => WalletTransaction.fromJson(
                Map<String, dynamic>.from(m as Map),
              ))
          .toList();
    }
  } catch (_) {}
  return <WalletTransaction>[];
}
