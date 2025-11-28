import 'dart:async';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'wallet_models.dart';

/// Lightweight client-side wallet service for OMK balance.
///
/// This service talks to the Queen backend over HTTP and caches the
/// last known balance locally so the UI can remain responsive even
/// when offline.
class OmkWalletService {
  OmkWalletService({required Dio dio, required String baseUrl})
      : _dio = dio,
        _baseUrl = baseUrl.trim().isEmpty
            ? 'https://omk-queen-ai-475745165557.us-central1.run.app'
            : baseUrl.trim();

  static const String _balanceKey = 'omk_wallet_balance_v1';
  static const String _welcomeKey = 'omk_wallet_welcome_bonus_applied_v1';

  final Dio _dio;
  final String _baseUrl;

  OmkWalletBalance? _cachedBalance;

  OmkWalletBalance? get cachedBalance => _cachedBalance;

  /// Load the last known balance from local storage.
  Future<OmkWalletBalance?> loadCachedBalance() async {
    if (_cachedBalance != null) return _cachedBalance;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_balanceKey);
    final decoded = decodeWalletBalance(raw);

    // One-time 20 OMK welcome bonus for fresh installs / empty wallets.
    final welcomeApplied = prefs.getBool(_welcomeKey) ?? false;
    if (!welcomeApplied && (decoded == null || _isZero(decoded.balanceOmk))) {
      final seeded = OmkWalletBalance(
        balanceOmk: '20',
        lastUpdated: DateTime.now(),
      );
      await _persistBalance(seeded);
      await prefs.setBool(_welcomeKey, true);
      _cachedBalance = seeded;
      return _cachedBalance;
    }

    _cachedBalance = decoded ?? OmkWalletBalance.zero();
    return _cachedBalance;
  }

  Future<void> _persistBalance(OmkWalletBalance balance) async {
    _cachedBalance = balance;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_balanceKey, encodeWalletBalance(balance));
  }

  /// Fetch the latest balance from Queen.
  Future<OmkWalletBalance> fetchBalance() async {
    final uri = '$_baseUrl/wallet/balance';
    final resp = await _dio.get<Map<String, dynamic>>(uri);
    final data = resp.data ?? <String, dynamic>{};
    final bal = OmkWalletBalance(
      balanceOmk: (data['balanceOmk'] as String?) ?? '0',
      lastUpdated: DateTime.now(),
    );
    await _persistBalance(bal);
    return bal;
  }

  /// Convenience wrapper that refreshes balance and returns true on
  /// success. On failure it leaves the cached balance unchanged.
  Future<bool> refreshBalance() async {
    try {
      await fetchBalance();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Attempt to spend the given amount of OMK for the provided reason.
  ///
  /// Returns `true` on success, `false` if Queen reports insufficient
  /// balance or if a non-fatal error occurs. Callers should treat
  /// `false` as "do not continue with the LLM call".
  Future<bool> spendOmk({
    required String amountOmk,
    required String reason,
  }) async {
    // First, try to satisfy the spend purely against the locally
    // cached balance (which may include the 20 OMK welcome bonus)
    // so that fresh installs can actually use their credits even if
    // the backend wallet starts at 0.
    try {
      final existing = _cachedBalance ?? await loadCachedBalance();
      final localStr = existing?.balanceOmk ?? '0';
      final local = double.tryParse(localStr.trim()) ?? 0.0;
      final amount = double.tryParse(amountOmk.trim()) ?? 0.0;

      if (amount > 0 && local + 1e-9 >= amount) {
        final remaining = local - amount;
        final updated = OmkWalletBalance(
          balanceOmk: remaining.toStringAsFixed(4),
          lastUpdated: DateTime.now(),
        );
        await _persistBalance(updated);
        return true;
      }
    } catch (_) {
      // If local math fails for any reason, fall back to server.
    }

    // Fallback: ask Queen to perform the spend and treat its answer
    // as the source of truth when available.
    final uri = '$_baseUrl/wallet/spend';
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        uri,
        data: <String, dynamic>{
          'amountOmk': amountOmk,
          'reason': reason,
        },
      );
      final data = resp.data ?? <String, dynamic>{};
      final success = (data['success'] as bool?) ?? false;
      final newBalance = data['balanceOmk'] as String?;
      if (newBalance != null) {
        await _persistBalance(OmkWalletBalance(
          balanceOmk: newBalance,
          lastUpdated: DateTime.now(),
        ));
      }
      return success;
    } catch (_) {
      return false;
    }
  }

  bool _isZero(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    final v = double.tryParse(trimmed);
    if (v == null) return false;
    return v.abs() < 1e-9;
  }
}
