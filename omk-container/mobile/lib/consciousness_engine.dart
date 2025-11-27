import 'package:dio/dio.dart';

import 'consciousness_registry.dart';
import 'state.dart';
import 'brain_actions.dart';
import 'llm_client.dart';
import 'omk_llm_client.dart';
import 'services/omk_wallet_service.dart';
import 'services/persona_pack_store.dart';

class ConsciousnessEngine {
  ConsciousnessEngine(this._registry);

  final ConsciousnessRegistry _registry;

  static Future<ConsciousnessEngine> load() async {
    final reg = await ConsciousnessRegistryStore.load();
    return ConsciousnessEngine(reg);
  }

  List<ChatMessage> _mergePersonaIntoHistory(
    List<ChatMessage> history,
    PersonaProfile? persona,
    UserProfile? userProfile,
  ) {
    final sys = _buildPersonaSystemMessage(persona, userProfile);
    if (sys == null) return history;
    return [sys, ...history];
  }

  ChatMessage? _buildPersonaSystemMessage(
    PersonaProfile? persona,
    UserProfile? userProfile,
  ) {
    if (persona == null && userProfile == null) return null;
    final parts = <String>[];
    if (persona != null) {
      if (persona.name.trim().isNotEmpty) {
        parts.add('Persona: ${persona.name.trim()}');
      }
      parts.add(
          'Tone: formality=${persona.formality}, concision=${persona.concision}');
      if (persona.keywords.trim().isNotEmpty) {
        parts.add('Keywords: ${persona.keywords.trim()}');
      }
      if (persona.bio.trim().isNotEmpty) {
        parts.add('Bio: ${persona.bio.trim()}');
      }
      if (persona.rules.trim().isNotEmpty) {
        parts.add('Rules: ${persona.rules.trim()}');
      }
    }
    if (userProfile != null) {
      if (userProfile.preferences.trim().isNotEmpty) {
        parts.add('User preferences: ${userProfile.preferences.trim()}');
      }
      if (userProfile.interests.trim().isNotEmpty) {
        parts.add('User interests: ${userProfile.interests.trim()}');
      }
      if (userProfile.location.trim().isNotEmpty) {
        parts.add('User location: ${userProfile.location.trim()}');
      }
    }
    final text = parts.join('\n');
    if (text.trim().isEmpty) return null;
    return ChatMessage(role: 'system', text: text.trim());
  }

  Future<String> generateReply(List<ChatMessage> history, String userInput) async {
    final active = _registry.active;
    final cfg = _registry.configFor(active);
    final label = _providerLabel(active);

    final persona = _registry.persona;
    final userProfile = _registry.userProfile;

    ChatMessage? systemMessage = _buildPersonaSystemMessage(persona, userProfile);
    try {
      final packs = await PersonaPackStore.instance.loadAll();
      final activePacks = packs.where((p) => p.active).toList();
      if (activePacks.isNotEmpty) {
        final summary = _buildPacksSummary(activePacks);
        final combinedText = [
          if (systemMessage != null) systemMessage.text,
          if (summary.trim().isNotEmpty) summary,
        ].where((s) => s.trim().isNotEmpty).join('\n\n');
        if (combinedText.trim().isNotEmpty) {
          systemMessage = ChatMessage(role: 'system', text: combinedText.trim());
        }
      }
    } catch (_) {}

    final enrichedHistory = systemMessage == null
        ? history
        : [systemMessage, ...history];
    final trimmedHistory = _trimHistoryForModel(enrichedHistory);

    final recentUserTexts = history
        .where((m) => m.role == 'user')
        .map((m) => m.text)
        .where((t) => t.trim().isNotEmpty)
        .toList(growable: false);

    final ctxSummary = recentUserTexts.isEmpty
        ? 'no prior messages'
        : '${recentUserTexts.length} prior message(s)';
    final personaName = persona?.name ?? 'My Hive';

    final dio = Dio();
    final wallet = OmkWalletService(
      dio: dio,
      baseUrl: cfg.baseUrl ?? '',
    );
    final omkClient = OmkLlmClient(
      dio: dio,
      wallet: wallet,
      queenBaseUrl: cfg.baseUrl ?? '',
    );

    String modelId;
    switch (active) {
      case ConsciousnessProviderId.openai:
        modelId = 'gpt';
        break;
      case ConsciousnessProviderId.gemini:
        modelId = 'gemini';
        break;
      case ConsciousnessProviderId.claude:
        modelId = 'claude';
        break;
      case ConsciousnessProviderId.grok:
        modelId = 'grok';
        break;
      case ConsciousnessProviderId.deepseek:
        modelId = 'deepseek';
        break;
      case ConsciousnessProviderId.local:
        modelId = 'local';
        break;
    }

    try {
      final answer = await omkClient.sendMessage(
        modelId: modelId,
        messages: trimmedHistory,
        // Persona packs are already fused into the system message above,
        // so we do not need to pass an explicit personaPackId here yet.
      );
      if (answer.trim().isNotEmpty) {
        return answer;
      }
    } on InsufficientOmkException {
      // Let the caller (UI) handle low-balance UX.
      rethrow;
    } catch (_) {
      // Fall through to debug response if provider call fails.
    }

    final actionIds = BrainActionCatalog.actions.map((a) => a.id).join(', ');

    return '[${label} • queen-relay • persona:$personaName] '
        '$userInput (context: $ctxSummary; tools: $actionIds)';
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
        return 'Local';
    }
  }

  List<ChatMessage> _trimHistoryForModel(List<ChatMessage> history) {
    if (history.isEmpty) return history;
    const maxMessages = 60;
    final hasSystem = history.first.role == 'system';
    if (!hasSystem) {
      if (history.length <= maxMessages) return history;
      return history.sublist(history.length - maxMessages);
    }
    final body = history.sublist(1);
    if (body.length <= maxMessages) {
      return history;
    }
    final tail = body.sublist(body.length - maxMessages);
    return [history.first, ...tail];
  }

  String _buildPacksSummary(List<PersonaPack> packs) {
    if (packs.isEmpty) return '';
    final lines = <String>[];
    lines.add('Imported consciousness packs active on this device:');
    for (final pack in packs) {
      lines.add('- ${pack.name}');
      final json = pack.personaJson;
      final assistant = json['assistant_persona'];
      final user = json['user_profile'];
      final shared = json['shared_memory'];

      if (assistant is Map) {
        final providerId = assistant['provider_id'];
        final styleNotes = assistant['style_notes'];
        if (providerId is String && providerId.trim().isNotEmpty) {
          lines.add('  • Provider: $providerId');
        }
        if (styleNotes is String && styleNotes.trim().isNotEmpty) {
          final snippet = styleNotes.length > 160
              ? '${styleNotes.substring(0, 160)}…'
              : styleNotes;
          lines.add('  • Assistant style: $snippet');
        }
      }

      if (user is Map) {
        final summary = user['summary'];
        if (summary is String && summary.trim().isNotEmpty) {
          final snippet = summary.length > 160
              ? '${summary.substring(0, 160)}…'
              : summary;
          lines.add('  • User profile: $snippet');
        }
      }

      if (shared is List) {
        int count = 0;
        for (final item in shared) {
          if (item is String && item.trim().isNotEmpty) {
            final snippet = item.length > 120
                ? '${item.substring(0, 120)}…'
                : item;
            lines.add('  • Memory: $snippet');
            count++;
            if (count >= 3) {
              break;
            }
          }
        }
      }
    }
    return lines.join('\n');
  }
}
