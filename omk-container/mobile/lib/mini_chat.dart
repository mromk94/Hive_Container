import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n.dart';
import 'state.dart';
import 'omk_llm_client.dart';
import 'wallet_screen.dart';
import 'consciousness_registry.dart';
import 'consciousness_engine.dart';

class MiniChatPanel extends ConsumerStatefulWidget {
  const MiniChatPanel({super.key});

  @override
  ConsumerState<MiniChatPanel> createState() => _MiniChatPanelState();
}

class _MiniChatPanelState extends ConsumerState<MiniChatPanel> {
  late final TextEditingController _controller;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = Strings.of(context);
    final messages = ref.watch(miniChatProvider);
    final reversed = messages.reversed.toList(growable: false);

    return Semantics(
      label: strings.miniChatTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              strings.miniChatTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              reverse: true,
              itemCount: reversed.length,
              itemBuilder: (context, index) {
                final msg = reversed[index];
                final isUser = msg.role == 'user';
                return Align(
                  alignment:
                      isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    constraints: const BoxConstraints(minHeight: 40, maxWidth: 260),
                    decoration: BoxDecoration(
                      color: isUser
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      msg.text,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isUser
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimary
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: strings.inputHint,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  label: 'Send message',
                  button: true,
                  child: IconButton(
                    iconSize: 28,
                    onPressed: () async {
                      final text = _controller.text.trim();
                      if (text.isEmpty) return;
                      _controller.clear();
                      _scrollToLatest();
                      try {
                        await ref
                            .read(miniChatProvider.notifier)
                            .sendWithConsciousness(text);
                      } on InsufficientOmkException catch (e) {
                        if (!context.mounted) return;
                        final choice = await showModalBottomSheet<String>(
                          context: context,
                          builder: (context) {
                            return SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      'Not enough OMK to call the cloud model (needs ~${e.estimatedCostOmk} OMK).',
                                      style:
                                          Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ),
                                  ListTile(
                                    leading: const Icon(
                                        Icons.account_balance_wallet_rounded),
                                    title: const Text('Open OMK Wallet'),
                                    onTap: () =>
                                        Navigator.of(context).pop('wallet'),
                                  ),
                                  ListTile(
                                    leading:
                                        const Icon(Icons.memory_rounded),
                                    title: const Text(
                                        'Use local brain for this reply'),
                                    onTap: () =>
                                        Navigator.of(context).pop('local'),
                                  ),
                                  ListTile(
                                    leading:
                                        const Icon(Icons.close_rounded),
                                    title: const Text('Cancel'),
                                    onTap: () =>
                                        Navigator.of(context).pop('cancel'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                        if (!context.mounted ||
                            choice == null ||
                            choice == 'cancel') return;
                        if (choice == 'wallet') {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const WalletScreen(),
                            ),
                          );
                          return;
                        }
                        if (choice == 'local') {
                          try {
                            final reg = await ConsciousnessRegistryStore.load();
                            reg.active = ConsciousnessProviderId.local;
                            await ConsciousnessRegistryStore.save(reg);
                            final engine = await ConsciousnessEngine.load();
                            final history = ref.read(miniChatProvider);
                            final reply =
                                await engine.generateReply(history, text);
                            if (reply.trim().isEmpty) return;
                            ref
                                .read(miniChatProvider.notifier)
                                .addAssistantMessage(reply.trim());
                          } catch (_) {}
                        }
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _QuickActionButton(
                  label: strings.quickAnalyze,
                  onTap: () => ref
                      .read(miniChatProvider.notifier)
                      .runQuickAction('analyze_page'),
                ),
                _QuickActionButton(
                  label: strings.quickSummarize,
                  onTap: () => ref
                      .read(miniChatProvider.notifier)
                      .runQuickAction('summarize'),
                ),
                _QuickActionButton(
                  label: strings.quickGuardMe,
                  onTap: () => ref
                      .read(miniChatProvider.notifier)
                      .runQuickAction('guard_me'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: OutlinedButton(
          onPressed: onTap,
          child: Text(label),
        ),
      ),
    );
  }
}
