import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'consciousness_registry.dart';
import 'state.dart';
import 'chat_store.dart';

class ConsciousnessControlRoomScreen extends ConsumerStatefulWidget {
  const ConsciousnessControlRoomScreen({super.key});

  @override
  ConsumerState<ConsciousnessControlRoomScreen> createState() => _ConsciousnessControlRoomScreenState();
}

class _ConsciousnessControlRoomScreenState extends ConsumerState<ConsciousnessControlRoomScreen> {
  ConsciousnessRegistry? _registry;
  bool _saving = false;

  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _personaNameController = TextEditingController();
  final _personaKeywordsController = TextEditingController();
  final _personaBioController = TextEditingController();
  final _personaRulesController = TextEditingController();
  final _providerInstructionsController = TextEditingController();
  final _threadIdController = TextEditingController();

  double _personaFormality = 50;
  double _personaConcision = 50;
  bool _useWebSession = false;
  bool _importingThread = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final reg = await ConsciousnessRegistryStore.load();
    setState(() {
      _registry = reg;
      final activeCfg = reg.configFor(reg.active);
      _apiKeyController.text = activeCfg.apiKey ?? '';
      _modelController.text = activeCfg.preferredModel ?? '';
      _useWebSession = activeCfg.useWebSession;
      final persona = reg.persona;
      if (persona != null) {
        _personaNameController.text = persona.name;
        _personaKeywordsController.text = persona.keywords;
        _personaBioController.text = persona.bio;
        _personaRulesController.text = persona.rules;
        _personaFormality = persona.formality.toDouble();
        _personaConcision = persona.concision.toDouble();
      }
    });
  }

  Future<void> _save() async {
    final reg = _registry;
    if (reg == null) return;
    setState(() {
      _saving = true;
    });
    final cfg = reg.configFor(reg.active);
    cfg.apiKey = _apiKeyController.text.trim().isEmpty
        ? null
        : _apiKeyController.text.trim();
    cfg.preferredModel = _modelController.text.trim().isEmpty
        ? null
        : _modelController.text.trim();
    cfg.useWebSession = _useWebSession;

    final baseRules = _personaRulesController.text.trim();
    final providerRules = _providerInstructionsController.text.trim();
    final mergedRules = [
      baseRules,
      providerRules,
    ].where((s) => s.isNotEmpty).join('\n\n');

    reg.persona = PersonaProfile(
      name: _personaNameController.text.trim().isEmpty
          ? 'My Hive'
          : _personaNameController.text.trim(),
      formality: _personaFormality.round(),
      concision: _personaConcision.round(),
      keywords: _personaKeywordsController.text.trim(),
      bio: _personaBioController.text.trim(),
      rules: mergedRules,
    );

    await ConsciousnessRegistryStore.save(reg);

    ref.read(selectedModelProvider.notifier).state = reg.active.name;

    if (mounted) {
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Consciousness settings saved.')),
      );
    }
  }

  Future<void> _importThread() async {
    final reg = _registry;
    if (reg == null) return;
    if (reg.active != ConsciousnessProviderId.openai) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thread import is currently supported for OpenAI only.')),
      );
      return;
    }
    final id = _threadIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a thread ID to import.')),
      );
      return;
    }
    final cfg = reg.configFor(ConsciousnessProviderId.openai);
    final key = cfg.apiKey?.trim();
    if (key == null || key.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set an OpenAI API key before importing a thread.')),
      );
      return;
    }
    setState(() {
      _importingThread = true;
    });
    try {
      final dio = Dio();
      final resp = await dio.get<Map<String, dynamic>>(
        'https://api.openai.com/v1/threads/$id/messages',
        options: Options(
          headers: <String, String>{
            'Authorization': 'Bearer $key',
          },
        ),
      );
      final data = resp.data;
      if (data == null) {
        throw StateError('Empty response');
      }
      final raw = data['data'];
      final messages = <ChatMessage>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map<String, dynamic>) {
            final role = (item['role'] as String?) ?? 'user';
            final content = item['content'];
            String text = '';
            if (content is List) {
              for (final c in content) {
                if (c is Map<String, dynamic>) {
                  final t = c['text'];
                  if (t is Map<String, dynamic>) {
                    final v = t['value'];
                    if (v is String && v.trim().isNotEmpty) {
                      text = v.trim();
                      break;
                    }
                  }
                }
              }
            }
            if (text.trim().isNotEmpty) {
              messages.add(ChatMessage(role: role, text: text.trim()));
            }
          }
        }
      }
      if (messages.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No messages imported from this thread.')),
        );
      } else {
        final serialized = messages.map((m) => m.toJson()).toList(growable: false);
        await ChatStore.save(serialized);
        if (mounted) {
          await ref.read(miniChatProvider.notifier).syncFromStore();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Thread imported into OMK chat.')),
          );
        }
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thread import failed in this build.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _importingThread = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reg = _registry;
    final scheme = Theme.of(context).colorScheme;
    final connectionLabel = () {
      if (reg == null) return '';
      final cfg = reg.configFor(reg.active);
      final hasKey = (cfg.apiKey != null && cfg.apiKey!.trim().isNotEmpty);
      final mode = _useWebSession
          ? (hasKey ? 'Web session + API key' : 'Web session')
          : (hasKey ? 'API key' : 'none');
      return 'Mode: $mode';
    }();
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Consciousness Control Room'),
      ),
      body: reg == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Active brain',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  connectionLabel,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.primary),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<ConsciousnessProviderId>(
                  value: reg.active,
                  items: ConsciousnessProviderId.values
                      .map(
                        (id) => DropdownMenuItem(
                          value: id,
                          child: Text(_providerLabel(id)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      reg.active = v;
                      final cfg = reg.configFor(v);
                      _apiKeyController.text = cfg.apiKey ?? '';
                      _modelController.text = cfg.preferredModel ?? '';
                    });
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Connection',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  value: _useWebSession,
                  onChanged: (v) {
                    setState(() {
                      _useWebSession = v;
                    });
                  },
                  title: const Text('Use web session if available'),
                  subtitle: const Text(
                    'For providers that support it, prefer ambient web sessions over direct API keys.',
                  ),
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API key or session token',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Preferred model (optional)',
                    hintText: 'e.g. gpt-4.1, gemini-1.5-pro-latest',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _threadIdController,
                  decoration: const InputDecoration(
                    labelText: 'OpenAI thread ID',
                    hintText: 'thread_...',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _importingThread ? null : _importThread,
                    icon: _importingThread
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cloud_download),
                    label: Text(
                      _importingThread
                          ? 'Importing thread…'
                          : 'Import thread into OMK chat',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Persona',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _personaNameController,
                  decoration: const InputDecoration(
                    labelText: 'Persona name',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Formality'),
                          Slider(
                            min: 0,
                            max: 100,
                            value: _personaFormality,
                            onChanged: (v) {
                              setState(() {
                                _personaFormality = v;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Concision'),
                          Slider(
                            min: 0,
                            max: 100,
                            value: _personaConcision,
                            onChanged: (v) {
                              setState(() {
                                _personaConcision = v;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _personaKeywordsController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Keywords',
                    hintText: 'Comma-separated traits or themes',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _personaBioController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Short bio',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _personaRulesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Rules / preferences',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _providerInstructionsController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Provider instructions',
                    hintText: 'Paste system prompt or custom instructions from ChatGPT, Gemini, etc.',
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.memory),
                    label: Text(_saving ? 'Saving…' : 'Save brain configuration'),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: scheme.surfaceVariant.withOpacity(0.5),
                  ),
                  child: const Text(
                    'In this build, provider keys and persona live only on this device. '
                    'Future versions will let this brain drive full OMK actions across mesh, AR, and security.',
                  ),
                ),
              ],
            ),
    );
  }

  String _providerLabel(ConsciousnessProviderId id) {
    switch (id) {
      case ConsciousnessProviderId.openai:
        return 'OpenAI';
      case ConsciousnessProviderId.gemini:
        return 'Gemini';
      case ConsciousnessProviderId.claude:
        return 'Claude';
      case ConsciousnessProviderId.grok:
        return 'Grok';
      case ConsciousnessProviderId.deepseek:
        return 'DeepSeek';
      case ConsciousnessProviderId.local:
        return 'Local / on-device';
    }
  }
}
