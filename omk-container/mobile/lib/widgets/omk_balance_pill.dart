import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../services/omk_wallet_service.dart';
import '../services/wallet_models.dart';
import '../wallet_screen.dart';

class OmkBalancePill extends StatefulWidget {
  const OmkBalancePill({super.key});

  @override
  State<OmkBalancePill> createState() => _OmkBalancePillState();
}

class _OmkBalancePillState extends State<OmkBalancePill> {
  late final OmkWalletService _wallet = OmkWalletService(
    dio: Dio(),
    baseUrl: '',
  );

  OmkWalletBalance? _balance;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await _wallet.loadCachedBalance();
    if (!mounted) return;
    setState(() {
      _balance = cached;
    });
    await _wallet.refreshBalance();
    if (!mounted) return;
    setState(() {
      _balance = _wallet.cachedBalance;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final balText = _balance?.balanceOmk ?? '--';
    return GestureDetector(
      onTap: () => showOmkCreditTopModal(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: scheme.surfaceVariant.withOpacity(0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.token_rounded, size: 14),
            const SizedBox(width: 6),
            Text(
              'OMK: $balText',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showOmkCreditTopModal(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'OMK credit',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (context, animation, secondaryAnimation) {
      return const _OmkCreditTopModal();
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.08),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _OmkCreditTopModal extends StatefulWidget {
  const _OmkCreditTopModal();

  @override
  State<_OmkCreditTopModal> createState() => _OmkCreditTopModalState();
}

class _OmkCreditTopModalState extends State<_OmkCreditTopModal>
    with SingleTickerProviderStateMixin {
  late final OmkWalletService _wallet = OmkWalletService(
    dio: Dio(),
    baseUrl: '',
  );

  OmkWalletBalance? _balance;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await _wallet.loadCachedBalance();
    if (!mounted) return;
    setState(() {
      _balance = cached;
    });
    await _wallet.refreshBalance();
    if (!mounted) return;
    setState(() {
      _balance = _wallet.cachedBalance;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bal = _balance?.balanceOmk ?? '--';
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth > 460 ? 420.0 : screenWidth - 32;
    return GestureDetector(
      onTap: () => Navigator.of(context).maybePop(),
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final t = _controller.value;
                  final tiltX = (t - 0.5) * 0.18;
                  final tiltY = (0.5 - t) * 0.22;
                  final scale = 0.96 + 0.06 * (1 - (t - 0.5).abs() * 2);
                  final transform = Matrix4.identity()
                    ..setEntry(3, 2, 0.0015)
                    ..rotateX(tiltX)
                    ..rotateY(tiltY)
                    ..scale(scale);
                  return Transform(
                    alignment: Alignment.center,
                    transform: transform,
                    child: SizedBox(
                      width: cardWidth,
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFFFF6C0),
                          Color(0xFFD4AF37),
                        ],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(0xFFFFFBE6),
                                Color(0xFFD4AF37),
                              ],
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.token_rounded,
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Available OMK',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF101016),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                bal,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      color: const Color(0xFF101016),
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap top up to load more OMK credit.',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: const Color(0xFF3A3012),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF101016),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const WalletScreen(),
                              ),
                            );
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Text('Top up'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
