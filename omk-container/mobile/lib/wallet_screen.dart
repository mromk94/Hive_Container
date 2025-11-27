import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'services/omk_wallet_service.dart';
import 'services/wallet_models.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late final OmkWalletService _wallet = OmkWalletService(
    dio: Dio(),
    baseUrl: '', // use default Queen URL stub for now
  );

  OmkWalletBalance? _balance;
  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final cached = await _wallet.loadCachedBalance();
    setState(() {
      _balance = cached;
      _loading = false;
    });
    await _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
    });
    await _wallet.refreshBalance();
    setState(() {
      _balance = _wallet.cachedBalance;
      _refreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bal = _balance ?? OmkWalletBalance.zero();

    return Scaffold(
      appBar: AppBar(
        title: const Text('OMK Wallet'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Balance',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withOpacity(0.15),
                    scheme.secondary.withOpacity(0.08),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Text(
                    _loading ? '--' : bal.balanceOmk,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'OMK',
                    style: theme.textTheme.titleMedium,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _refreshing ? null : _refresh,
                    icon: _refreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bal.lastUpdated.millisecondsSinceEpoch == 0
                  ? 'Last updated: never'
                  : 'Last updated: ${bal.lastUpdated.toLocal()}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            Text(
              'Actions',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                // Placeholder top-up behavior; future phase will deep-link
                // into Queen or a dedicated top-up flow.
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Top-up flow will be wired in a later phase.'),
                  ),
                );
              },
              icon: const Icon(Icons.account_balance_wallet_rounded),
              label: const Text('Top up OMK'),
            ),
            const SizedBox(height: 16),
            Text(
              'Usage (coming soon)',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Recent wallet activity and per-model spend will appear here in a later build.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
