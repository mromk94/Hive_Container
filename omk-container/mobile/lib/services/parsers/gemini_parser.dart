import '../chat_import_models.dart';
import 'generic_parser.dart';

/// Parser for Gemini / Bard shared chats at `https://g.co/bard/share/...` and
/// `https://g.co/gemini/share/...`.
///
/// This implementation first tries to recover role/text pairs from JSON-like
/// snippets embedded in the HTML (Gemini often serialises turns into a
/// JavaScript payload). If that fails it falls back to the generic parser.
class GeminiChatParser implements ChatParser {
  final GenericChatParser _fallback = GenericChatParser();

  @override
  Future<List<ImportedMessage>> parse(String url, String html) async {
    final messages = <ImportedMessage>[];

    // Heuristic: look for occurrences of "role":"user" or "role":"model"
    // accompanied by a "text" field. In practice Gemini's internal schema
    // may evolve, but this covers a common pattern.
    final roleTextRegex = RegExp(
      r'"role"\s*:\s*"(user|model|assistant)"[^{\]]+?"text"\s*:\s*"(.*?)"',
      caseSensitive: false,
      dotAll: true,
    );

    final matches = roleTextRegex.allMatches(html).toList();
    if (matches.isNotEmpty) {
      var index = 0;
      for (final m in matches) {
        if (m.groupCount < 2) continue;
        final rawRole = (m.group(1) ?? 'user').toLowerCase();
        final role = (rawRole == 'model' || rawRole == 'assistant')
            ? ImportedRole.assistant
            : ImportedRole.user;
        var rawText = m.group(2) ?? '';

        rawText = rawText
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\r', '\r')
            .replaceAll(r'\t', '\t')
            .replaceAll(r'\"', '"');

        final text = rawText.trim();
        if (text.isEmpty) continue;

        messages.add(
          ImportedMessage(
            id: 'gemini_json_$index',
            role: role,
            text: text,
            index: index,
          ),
        );
        index++;
        if (messages.length >= 80) {
          break;
        }
      }
    }

    if (messages.length >= 2) {
      return messages;
    }

    // Fallback: generic HTML-based heuristics.
    return _fallback.parse(url, html);
  }
}
