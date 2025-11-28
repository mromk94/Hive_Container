import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n.dart';
import 'state.dart';
import 'chat_store.dart';
import 'consciousness_control_room_screen.dart';
import 'omk_llm_client.dart';
import 'wallet_screen.dart';
import 'consciousness_registry.dart';
import 'consciousness_engine.dart';
import 'permissions_screen.dart';

class AssistantScreen extends ConsumerWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    final dark = ref.watch(assistantDarkModeProvider);

    return Stack(
      children: [
        // Dim + blur the underlying OMK UI.
        Positioned.fill(
          child: GestureDetector(
            onTap: () =>
                ref.read(assistantOpenProvider.notifier).state = false,
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
        ),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                constraints:
                    const BoxConstraints(maxWidth: 420, maxHeight: 560),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: const Color(0xFFD4AF37),
                    width: 2,
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: dark
                        ? const [
                            Color(0xFF101018),
                            Color(0xFF050509),
                          ]
                        : const [
                            Color(0xFFFFF6DD),
                            Color(0xFFFFEECB),
                          ],
                  ),
                ),
                child: _OmkAssistantCard(strings: strings, theme: theme, showClose: true),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Embedded in-app version of the OMK Assistant, without backdrop/dimming.
class EmbeddedAssistantScreen extends ConsumerWidget {
  const EmbeddedAssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final strings = Strings.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child:
          _OmkAssistantCard(strings: strings, theme: theme, showClose: false),
    );
  }
}

class _OmkAssistantCard extends ConsumerWidget {
  const _OmkAssistantCard({
    required this.strings,
    required this.theme,
    required this.showClose,
  });

  final Strings strings;
  final ThemeData theme;
  final bool showClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = theme.textTheme;
    final dark = ref.watch(assistantDarkModeProvider);
    final model = ref.watch(selectedModelProvider);
    final brainLabel = switch (model) {
      'openai' => 'OpenAI',
      'gemini' => 'Gemini',
      'claude' => 'Claude',
      'grok' => 'Grok',
      'deepseek' => 'DeepSeek',
      'local' => 'Local',
      _ => 'Gemini',
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Connection status bar: CLOUD / MESH / LOCAL.
          Container(
            height: 22,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: dark
                  ? const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0x33101018),
                        Color(0x66101018),
                      ],
                    )
                  : const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Color(0x33D4AF37),
                        Color(0x66D4AF37),
                      ],
                    ),
            ),
            child: Row(
              children: [
                _ConnectionPill(
                  label: 'CLOUD',
                  isActive: true,
                  textTheme: textTheme,
                ),
                _ConnectionPill(
                  label: 'MESH',
                  isActive: false,
                  textTheme: textTheme,
                ),
                _ConnectionPill(
                  label: 'LOCAL',
                  isActive: false,
                  textTheme: textTheme,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // OMK badge.
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFFFFF6C0),
                      Color(0xFFD4AF37),
                    ],
                  ),
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF101016),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'OMK Assistant',
                style: textTheme.titleMedium?.copyWith(
                  color: dark ? Colors.white : const Color(0xFF101016),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ConsciousnessControlRoomScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor:
                      dark ? Colors.white : const Color(0xFF101016),
                ),
                icon: const Icon(Icons.memory, size: 18),
                label: Text(
                  brainLabel,
                  style: textTheme.labelMedium,
                ),
              ),
              IconButton(
                onPressed: () async {
                  final newValue = !dark;
                  ref.read(assistantDarkModeProvider.notifier).state = newValue;
                  await ThemeStore.save(newValue);
                },
                icon: Icon(
                  dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              if (showClose)
                IconButton(
                  onPressed: () =>
                      ref.read(assistantOpenProvider.notifier).state = false,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Color(0xFF101016),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _OmkMiniChat(strings: strings),
          ),
        ],
      ),
    );
  }
}

class _OmkMiniChat extends ConsumerStatefulWidget {
  const _OmkMiniChat({required this.strings});

  final Strings strings;

  @override
  ConsumerState<_OmkMiniChat> createState() => _OmkMiniChatState();
}

class _OmkMiniChatState extends ConsumerState<_OmkMiniChat> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    // Ensure in-app chat pulls the latest history (including any
    // messages created by the floating bubble) when this widget is
    // first shown.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(miniChatProvider.notifier).syncFromStore();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(miniChatProvider);
    final reversed = messages.reversed.toList(growable: false);
    final textTheme = Theme.of(context).textTheme;
    final hasMic = ref.watch(microphonePermissionGrantedProvider);

    final dark = ref.watch(assistantDarkModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            reverse: true,
            itemCount: reversed.length,
            itemBuilder: (context, index) {
              final msg = reversed[index];
              final isUser = msg.role == 'user';
              return Align(
                alignment:
                    isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints:
                      const BoxConstraints(minHeight: 40, maxWidth: 280),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFE6C76A),
                              Color(0xFFD4AF37),
                            ],
                          )
                        : dark
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFF2A2A3A),
                                  Color(0xFF151520),
                                ],
                              )
                            : const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFFFCF4D8),
                                  Color(0xFFE9D8A0),
                                ],
                              ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: textTheme.bodyMedium?.copyWith(
                      color: isUser
                          ? const Color(0xFF101016)
                          : Colors.white,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: widget.strings.inputHint,
                  filled: true,
                  fillColor:
                      dark ? const Color(0xCC101018) : Colors.white.withOpacity(0.9),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(
                      color: Color(0xFFFFE7A0),
                      width: 1.4,
                    ),
                  ),
                ),
                style: textTheme.bodyMedium?.copyWith(
                  color: dark ? Colors.white : const Color(0xFF101016),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF3A3012),
              ),
              child: IconButton(
                iconSize: 22,
                padding: EdgeInsets.zero,
                onPressed: () async {
                  final micGranted =
                      ref.read(microphonePermissionGrantedProvider);
                  if (!micGranted) {
                    if (!mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PermissionsScreen(),
                      ),
                    );
                    return;
                  }
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Voice input is not wired to transcription in this build.'),
                    ),
                  );
                },
                icon: Icon(
                  Icons.mic_rounded,
                  color: hasMic ? Colors.white : Colors.white70,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFD4AF37),
              ),
              child: IconButton(
                iconSize: 22,
                padding: EdgeInsets.zero,
                onPressed: () async {
                  final text = _controller.text.trim();
                  if (text.isEmpty) return;
                  _controller.clear();
                  try {
                    await ref
                        .read(miniChatProvider.notifier)
                        .sendWithConsciousness(text);
                  } on InsufficientOmkException catch (e) {
                    if (!mounted) return;
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
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                              ListTile(
                                leading: const Icon(Icons.account_balance_wallet_rounded),
                                title: const Text('Open OMK Wallet'),
                                onTap: () => Navigator.of(context).pop('wallet'),
                              ),
                              ListTile(
                                leading: const Icon(Icons.memory_rounded),
                                title: const Text('Use local brain for this reply'),
                                onTap: () => Navigator.of(context).pop('local'),
                              ),
                              ListTile(
                                leading: const Icon(Icons.close_rounded),
                                title: const Text('Cancel'),
                                onTap: () => Navigator.of(context).pop('cancel'),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                    if (!mounted || choice == null || choice == 'cancel') return;
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
                        final reply = await engine.generateReply(history, text);
                        if (reply.trim().isEmpty) return;
                        ref
                            .read(miniChatProvider.notifier)
                            .addAssistantMessage(reply.trim());
                      } catch (_) {}
                    }
                  }
                },
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFF3CC),
              Color(0xFFF7DE9A),
            ],
          ),
          border: Border.all(color: const Color(0xFFD4AF37)),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: const Color(0xFF101016),
              ),
        ),
      ),
    );
  }
}

class _ConnectionPill extends StatelessWidget {
  const _ConnectionPill({
    required this.label,
    required this.isActive,
    required this.textTheme,
  });

  final String label;
  final bool isActive;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: textTheme.labelSmall?.copyWith(
            color: isActive
                ? const Color(0xFFD4AF37)
                : Colors.white.withOpacity(0.6),
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
