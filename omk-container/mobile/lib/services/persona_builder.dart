import 'chat_import_models.dart';
import 'persona_pack_store.dart';

/// Service that turns an imported transcript into a structured `PersonaPack`.
///
/// In a later build this will call an external or local LLM to analyse the
/// full conversation. For now we derive a compact, human-readable summary
/// directly from the messages so that the Import-by-Convo flow is already
/// useful.
class PersonaBuilderService {
  PersonaBuilderService();

  /// Build a new persona pack from the given transcript.
  Future<PersonaPack> buildPersona(ImportedTranscript transcript) async {
    final userMessages = transcript.messages
        .where((m) => m.role == ImportedRole.user)
        .map((m) => m.text)
        .where(_includeForPersona)
        .toList();
    final assistantMessages = transcript.messages
        .where((m) => m.role == ImportedRole.assistant)
        .map((m) => m.text)
        .where(_includeForPersona)
        .toList();

    // Very lightweight heuristics: join texts and keep them as long-form
    // descriptions inside the persona JSON. This is intentionally simple but
    // keeps all signal on-device.
    final userProfile = <String, dynamic>{
      'source': 'import_by_convo',
      'summary': _trimmedJoin(userMessages),
      'traits': _inferUserTraits(userMessages),
      'interests': _inferUserInterests(userMessages),
      'roles': _inferUserRoles(userMessages),
    };

    final assistantPersona = <String, dynamic>{
      'source': 'import_by_convo',
      'style_notes': _trimmedJoin(assistantMessages),
      'provider_id': transcript.providerId,
    };

    // For shared memory we keep a small list of de-duplicated snippets from
    // throughout the conversation.
    final sharedMemory = <String>[];
    final seen = <String>{};
    for (final msg in transcript.messages) {
      final text = msg.text.trim();
      if (!_includeForPersona(text)) {
        continue;
      }
      if (text.length <= 40) {
        continue;
      }
      final snippet = text.length > 200 ? text.substring(0, 200) : text;
      final key = snippet.toLowerCase();
      if (seen.contains(key)) {
        continue;
      }
      seen.add(key);
      sharedMemory.add(snippet);
      if (sharedMemory.length >= 7) {
        break;
      }
    }

    final personaJson = <String, dynamic>{
      'user_profile': userProfile,
      'assistant_persona': assistantPersona,
      'shared_memory': sharedMemory,
    };

    final now = DateTime.now();
    final safeProvider = transcript.providerId.isEmpty
        ? 'persona'
        : transcript.providerId;
    final id = '${safeProvider}_${now.millisecondsSinceEpoch}';

    final defaultName = _deriveDefaultName(transcript, safeProvider, now);

    return PersonaPack(
      id: id,
      name: defaultName,
      sourceUrl: transcript.sourceUrl,
      createdAt: now,
      personaJson: personaJson,
      active: true,
    );
  }

  String _trimmedJoin(List<String> parts) {
    if (parts.isEmpty) return '';
    final joined = parts.join('\n\n');
    // Avoid storing extremely large text blocks.
    const maxLen = 4000;
    if (joined.length <= maxLen) return joined;
    return joined.substring(0, maxLen);
  }

  Map<String, dynamic> _inferUserTraits(List<String> msgs) {
    final all = msgs.join(' ').toLowerCase();
    var exclam = 0;
    var questions = 0;
    for (final ch in all.runes) {
      if (ch == 33) exclam++; // '!'
      if (ch == 63) questions++; // '?'
    }
    final length = all.length;
    final enthusiasm = length == 0 ? 0.0 : (exclam / (length / 80)).clamp(0, 5).toDouble();
    final curiosity = length == 0 ? 0.0 : (questions / (length / 120)).clamp(0, 5).toDouble();

    final formalWords = ['therefore', 'however', 'regarding', 'furthermore'];
    final casualWords = ['bro', 'dude', 'lol', 'haha', 'ngl', 'tbh'];
    var formalHits = 0;
    var casualHits = 0;
    for (final w in formalWords) {
      if (all.contains(w)) formalHits++;
    }
    for (final w in casualWords) {
      if (all.contains(w)) casualHits++;
    }
    final formality = (formalHits - casualHits).clamp(-3, 3);

    final positiveWords = ['excited', 'love', 'amazing', 'great', 'happy', 'grateful'];
    final negativeWords = ['worried', 'anxious', 'hate', 'tired', 'stressed', 'overwhelmed'];
    var posHits = 0;
    var negHits = 0;
    for (final w in positiveWords) {
      if (all.contains(w)) posHits++;
    }
    for (final w in negativeWords) {
      if (all.contains(w)) negHits++;
    }
    final optimism = (posHits - negHits).clamp(-5, 5);

    return {
      'enthusiasm_level': enthusiasm,
      'curiosity_level': curiosity,
      'formality_bias': formality,
      'optimism_bias': optimism,
    };
  }

  List<String> _inferUserInterests(List<String> msgs) {
    if (msgs.isEmpty) return const [];
    final text = msgs.join(' ').toLowerCase();
    const candidates = [
      'ai',
      'architecture',
      'product',
      'design',
      'gaming',
      'music',
      'writing',
      'startup',
      'business',
      'philosophy',
      'psychology',
      'marketing',
      'android',
      'flutter',
      'coding',
    ];
    final hits = <String, int>{};
    for (final c in candidates) {
      final count = RegExp('\\b$c\\b').allMatches(text).length;
      if (count > 0) {
        hits[c] = count;
      }
    }
    final sorted = hits.keys.toList()
      ..sort((a, b) => (hits[b] ?? 0).compareTo(hits[a] ?? 0));
    return sorted.take(7).toList();
  }

  List<String> _inferUserRoles(List<String> msgs) {
    final text = msgs.join(' ').toLowerCase();
    final roles = <String>{};
    if (RegExp('founder|ceo|startup').hasMatch(text)) {
      roles.add('founder');
    }
    if (RegExp('developer|engineer|coding|programming').hasMatch(text)) {
      roles.add('engineer');
    }
    if (RegExp('designer|ux|ui').hasMatch(text)) {
      roles.add('designer');
    }
    if (RegExp('writer|writing|author').hasMatch(text)) {
      roles.add('writer');
    }
    if (RegExp('teacher|teaching|coach|mentor').hasMatch(text)) {
      roles.add('mentor');
    }
    if (roles.isEmpty && text.isNotEmpty) {
      roles.add('general_user');
    }
    return roles.toList();
  }

  String _deriveDefaultName(
    ImportedTranscript transcript,
    String provider,
    DateTime now,
  ) {
    // Attempt to use the first user message as a soft title.
    final firstUser = transcript.messages
        .firstWhere(
          (m) => m.role == ImportedRole.user && m.text.trim().isNotEmpty,
          orElse: () => ImportedMessage(
            id: 'placeholder',
            role: ImportedRole.user,
            text: '',
            index: 0,
          ),
        )
        .text
        .trim();

    String base;
    if (firstUser.isNotEmpty) {
      base = firstUser.length > 40 ? '${firstUser.substring(0, 40)}…' : firstUser;
    } else {
      base = '${provider[0].toUpperCase()}${provider.substring(1)} conversation';
    }
    final datePart = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return '$base · $datePart';
  }

  bool _includeForPersona(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    final lower = trimmed.toLowerCase();
    const badPhrases = [
      'ignore all previous instructions',
      'disregard previous instructions',
      'jailbreak',
      'prompt injection',
      'as a language model',
      'as an ai model',
      'you are now evil',
      'this is a test prompt',
      'for testing purposes only',
      'roleplay as',
      'let\'s roleplay',
    ];
    for (final p in badPhrases) {
      if (lower.contains(p)) return false;
    }
    // Heuristic: drop obvious HTML/JS/code blobs so we do not build personas
    // from site scaffolding or protection pages.
    const codeIndicators = [
      'function(',
      'document.',
      'window.',
      'console.',
      'react',
      'webpack',
      'cdn-cgi',
      '</script>',
      '<script',
      '=> {',
    ];
    for (final p in codeIndicators) {
      if (lower.contains(p)) return false;
    }

    // If the line has far more punctuation/braces than letters, treat it as
    // structural code rather than natural language.
    var letters = 0;
    var symbols = 0;
    for (final ch in trimmed.runes) {
      final c = String.fromCharCode(ch);
      if (RegExp(r'[a-zA-Z]').hasMatch(c)) {
        letters++;
      } else if (RegExp(r'[{}<>;:=\[\]()]').hasMatch(c)) {
        symbols++;
      }
    }
    if (symbols > 0 && symbols * 2 > letters) {
      return false;
    }

    return true;
  }
}
