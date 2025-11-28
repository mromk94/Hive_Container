import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'assistant_screen.dart';
import 'l10n.dart';
import 'mesh_status_screen.dart';
import 'onboarding.dart';
import 'overlay_lifecycle.dart';
import 'settings_screen.dart';
import 'state.dart';
import 'url_risk_model.dart';
import 'autonomy_engine.dart';
import 'mesh_transport_bridge.dart';
import 'mesh_discovery_provider.dart';
import 'topology_screen.dart';
import 'community_board_screen.dart';
import 'knowledge_pool_screen.dart';
import 'event_tags_screen.dart';
import 'learning_pulse_screen.dart';
import 'community_milestones_screen.dart';
import 'ai_villages_screen.dart';
import 'resource_tracker_screen.dart';
import 'sync_policy_screen.dart';
import 'consciousness_control_room_screen.dart';
import 'services/chat_import_models.dart';
import 'services/chat_importer.dart';
import 'services/chat_webview_importer.dart';
import 'services/persona_builder.dart';
import 'services/persona_pack_store.dart';
import 'import_bridge.dart';
import 'persona_summary_screen.dart';
import 'widgets/omk_balance_pill.dart';
import 'wallet_screen.dart';

final GlobalKey<NavigatorState> omkNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  onboardingCompletedBootstrap =
      prefs.getBool('omk_onboarding_completed_v1') ?? false;
  UrlRiskModel.instance.load();
  AutonomyEngine.load();
  // Initialize mesh transport bridge to start listening for mesh events.
  MeshTransportBridge.instance;
  ImportBridge.instance.init(omkNavigatorKey);
  runApp(const ProviderScope(child: OmkContainerApp()));
}

class OmkContainerApp extends ConsumerWidget {
  const OmkContainerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(assistantDarkModeProvider);
    return MaterialApp(
      title: Strings.of(context).appTitle,
      theme: omkTheme(dark),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        StringsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: Strings.supportedLocales,
      navigatorKey: omkNavigatorKey,
      builder: (context, child) => OverlayLifecycle(
        child: _AssistantShell(child: child ?? const SizedBox.shrink()),
      ),
      home: const _RootSwitcher(),
    );
  }
}

class _ImportConsciousnessButton extends StatefulWidget {
  const _ImportConsciousnessButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ImportConsciousnessButton> createState() => _ImportConsciousnessButtonState();
}

class _ImportConsciousnessButtonState extends State<_ImportConsciousnessButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ScaleTransition(
      scale: Tween<double>(begin: 0.96, end: 1.04).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 200,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.primary.withOpacity(0.9),
                scheme.secondary,
              ],
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.cloud_download_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Import consciousness',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportMethodsSheet extends StatelessWidget {
  const _ImportMethodsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Import consciousness',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Choose how to bring an existing AI into OMK. Conversation-first is recommended.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ConvoImportScreen()),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary,
                            scheme.secondary,
                          ],
                        ),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Import by conversation',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: scheme.primary.withOpacity(0.1),
                                ),
                                child: Text(
                                  'Primary',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: scheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Treat a whole chat as a living memory. OMK will absorb tone, prefs, and context.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ConsciousnessControlRoomScreen(),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.surfaceVariant,
                      ),
                      child: const Icon(Icons.confirmation_number_outlined),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Import by provider thread ID',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Use an OpenAI thread (and later others) to seed OMK chat directly.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConvoImportScreen extends StatefulWidget {
  const ConvoImportScreen({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  State<ConvoImportScreen> createState() => _ConvoImportScreenState();
}

class _ConvoImportScreenState extends State<ConvoImportScreen> {
  final _urlController = TextEditingController();
  final _importer = ChatImporterService();
  final _personaBuilder = PersonaBuilderService();
  final _manualTextController = TextEditingController();

  ImportedTranscript? _transcript;
  bool _loadingTranscript = false;
  bool _buildingPersona = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final url = widget.initialUrl;
    if (url != null && url.trim().isNotEmpty) {
      _urlController.text = url.trim();
      // Defer preview until first frame so the UI can show progress state.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _previewTranscript();
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _manualTextController.dispose();
    super.dispose();
  }

  Future<void> _previewTranscript() async {
    final url = _urlController.text.trim();
    final manual = _manualTextController.text.trim();
    if (url.isEmpty && manual.isEmpty) {
      setState(() {
        _error = 'Paste a shared chat link or conversation text first.';
      });
      return;
    }
    setState(() {
      _loadingTranscript = true;
      _error = null;
      _transcript = null;
    });
    try {
      // Stage 0: if the user provided manual text, build a transcript directly
      // from that and skip network-based import.
      ImportedTranscript? t;
      if (manual.isNotEmpty) {
        final messages = _buildManualMessages(manual);
        if (messages.length >= 2) {
          t = ImportedTranscript(
            sourceUrl: url,
            providerId: 'manual',
            fetchedAt: DateTime.now(),
            messages: messages,
          );
        }
      }

      if (t == null) {
        final provider = _importer.detectProvider(url);
        if (mounted) {
          t = await ChatWebViewImporter.importViaWebView(context, url, provider);
        }
        if (t == null) {
          setState(() {
            _error =
                'OMK could not read this chat in browser-mode. If this page is private or heavily protected, scroll down and paste the conversation text manually.';
          });
        }
      }
      setState(() {
        _transcript = t;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loadingTranscript = false;
        });
      }
    }
  }

  List<ImportedMessage> _buildManualMessages(String raw) {
    final text = raw.replaceAll('\r', '').trim();
    if (text.isEmpty) return const [];
    final parts = text
        .split(RegExp('\\n{2,}'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    final out = <ImportedMessage>[];
    var role = ImportedRole.user;
    for (var i = 0; i < parts.length; i++) {
      final chunk = parts[i];
      out.add(ImportedMessage(
        id: 'manual_$i',
        role: role,
        text: chunk,
        index: i,
      ));
      role = role == ImportedRole.user ? ImportedRole.assistant : ImportedRole.user;
      if (out.length >= 80) break;
    }
    return out;
  }

  Future<void> _buildPersona() async {
    final transcript = _transcript;
    if (transcript == null) {
      setState(() {
        _error = 'Preview a conversation before building a persona.';
      });
      return;
    }
    setState(() {
      _buildingPersona = true;
      _error = null;
    });
    try {
      final pack = await _personaBuilder.buildPersona(transcript);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PersonaSummaryScreen(draft: pack),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _buildingPersona = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final transcript = _transcript;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import by conversation'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bring an existing AI conversation into OMK.',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Paste a shared chat link from ChatGPT, Claude, Gemini, Grok or another LLM. '
              'OMK will turn that conversation into a reusable consciousness pack.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Shared chat link',
                hintText: 'https://chat.openai.com/share/...',
              ),
            ),
            const SizedBox(height: 8),
            if (_error != null) ...[
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _manualTextController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Manual conversation text (optional)',
                hintText: 'If automatic import fails, paste the chat text here.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadingTranscript ? null : _previewTranscript,
                icon: _loadingTranscript
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.remove_red_eye_outlined),
                label: Text(
                  _loadingTranscript ? 'Loading transcript…' : 'Preview transcript',
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (transcript != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            color: scheme.surfaceVariant,
                          ),
                          child: Text(
                            'Provider: ${transcript.providerId}',
                            style: theme.textTheme.labelSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${transcript.messages.length} messages',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (transcript.messages.length <= 2 &&
                        transcript.messages.isNotEmpty &&
                        transcript.messages.first.text.startsWith(
                            'OMK could not fully import this conversation'))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'This is a fallback import. OMK could not fully read this chat in this build.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.error),
                        ),
                      ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: scheme.surfaceVariant.withOpacity(0.7),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: ListView.builder(
                          itemCount: transcript.messages.length.clamp(0, 12),
                          itemBuilder: (context, index) {
                            final msg = transcript.messages[index];
                            final isUser = msg.role == ImportedRole.user;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Align(
                                alignment:
                                    isUser ? Alignment.centerLeft : Alignment.centerRight,
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 320),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: isUser
                                        ? scheme.surface
                                        : scheme.primary.withOpacity(0.12),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isUser ? 'User' : 'Assistant',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: scheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        msg.text,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _buildingPersona ? null : _buildPersona,
                        icon: _buildingPersona
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.memory),
                        label: Text(
                          _buildingPersona
                              ? 'Building persona…'
                              : 'Build persona from this chat',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RootSwitcher extends ConsumerWidget {
  const _RootSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completed = ref.watch(onboardingCompletedProvider);
    if (!completed) {
      return const OnboardingFlow();
    }
    return const HomeShell();
  }
}

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = Strings.of(context);
    final navIndex = ref.watch(navIndexProvider);

    // When user navigates to the Chat tab, pull in any new messages
    // written by the floating bubble since we last looked.
    ref.listen<int>(navIndexProvider, (previous, next) {
      if (next == 1) {
        ref.read(miniChatProvider.notifier).syncFromStore();
      }
    });
    ref.listen<bool>(omkPowerOnProvider, (previous, next) {
      ImportBridge.instance.setClipboardWatcherEnabled(next);
    });
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.appTitle),
        actions: [
          IconButton(
            tooltip: 'Mesh status',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MeshStatusScreen()),
              );
            },
            icon: const Icon(Icons.wifi_tethering),
          ),
        ],
      ),
      body: IndexedStack(
        index: navIndex,
        children: const [
          _HomeTab(),
          _ChatTab(),
          MeshCommunityTab(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navIndex,
        onDestinationSelected: (index) {
          ref.read(navIndexProvider.notifier).state = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.wifi_tethering_outlined),
            selectedIcon: Icon(Icons.wifi_tethering),
            label: 'Mesh',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOn = ref.watch(omkPowerOnProvider);
    final peersAsync = ref.watch(allowedMeshPeersStreamProvider);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'OMK Container prepares your device to act as a living node in the Hive. '
                'Turn OMK on to enable mesh discovery, safety checks, and the floating assistant bubble.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            final newValue = !isOn;
            ref.read(omkPowerOnProvider.notifier).state = newValue;
            ref.read(floatingEnabledProvider.notifier).state = newValue;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isOn
                  ? const RadialGradient(
                      colors: [
                        Color(0xFFFFF6C0),
                        Color(0xFFD4AF37),
                      ],
                    )
                  : const RadialGradient(
                      colors: [
                        Color(0xFFCCCCCC),
                        Color(0xFF888888),
                      ],
                    ),
              boxShadow: [
                if (isOn)
                  const BoxShadow(
                    color: Color(0x80D4AF37),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Center(
              child: Icon(
                isOn ? Icons.power_settings_new_rounded : Icons.power_settings_new,
                size: 40,
                color: isOn ? const Color(0xFF101016) : Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => WalletScreen(),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF101016),
                    Color(0xFF3A3012),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFFFFF6C0),
                          Color(0xFFD4AF37),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.token_rounded,
                        color: Color(0xFF101016),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'OMK credit',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to see available OMK and top up before long runs.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // The compact pill still opens the 3D OMK credit
                  // top-up modal, but the large card now routes
                  // directly into the full Wallet screen.
                  const OmkBalancePill(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: peersAsync.when(
            data: (peers) {
              final count = peers.length;
              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mesh pulse',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        count == 0
                            ? 'No peers nearby yet'
                            : '$count mesh peer${count == 1 ? '' : 's'} nearby',
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: 16),
        _ImportConsciousnessButton(
          onTap: () {
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (sheetContext) => const _ImportMethodsSheet(),
            );
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _ChatTab extends ConsumerWidget {
  const _ChatTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const EmbeddedAssistantScreen();
  }
}
class MeshCommunityTab extends StatelessWidget {
  const MeshCommunityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Mesh & Community',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Explore your local mesh health, nearby AI villages, and community signals.',
        ),
        const SizedBox(height: 16),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: const Icon(Icons.wifi_tethering),
            title: const Text('Mesh status'),
            subtitle: const Text('View connectivity mode and recent mesh alerts.'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MeshStatusScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: const Icon(Icons.hub_outlined),
            title: const Text('Topology'),
            subtitle: const Text('See how many links your node sees right now.'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TopologyScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: const Icon(Icons.location_city_outlined),
            title: const Text('AI villages'),
            subtitle: const Text('Browse logical clusters of OMK nodes.'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiVillagesScreen()),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Community signals',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MeshNavChip(
              icon: Icons.forum_outlined,
              label: 'Board',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CommunityBoardScreen()),
                );
              },
            ),
            _MeshNavChip(
              icon: Icons.lightbulb_outline,
              label: 'Knowledge',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const KnowledgePoolScreen()),
                );
              },
            ),
            _MeshNavChip(
              icon: Icons.label_outline,
              label: 'Tags',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EventTagsScreen()),
                );
              },
            ),
            _MeshNavChip(
              icon: Icons.timelapse_outlined,
              label: 'Pulses',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LearningPulseScreen()),
                );
              },
            ),
            _MeshNavChip(
              icon: Icons.emoji_events_outlined,
              label: 'Milestones',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CommunityMilestonesScreen()),
                );
              },
            ),
            _MeshNavChip(
              icon: Icons.bolt_outlined,
              label: 'Resources',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ResourceTrackerScreen()),
                );
              },
            ),
            _MeshNavChip(
              icon: Icons.tune_outlined,
              label: 'Sync policy',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SyncPolicyScreen()),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _MeshNavChip extends StatelessWidget {
  const _MeshNavChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Theme.of(context).colorScheme.surfaceVariant,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _AssistantShell extends ConsumerWidget {
  const _AssistantShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(assistantOpenProvider);
    return Stack(
      children: [
        child,
        if (open) const AssistantScreen(),
      ],
    );
  }
}
