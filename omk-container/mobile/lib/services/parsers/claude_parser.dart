import '../chat_import_models.dart';
import 'generic_parser.dart';

/// Parser for Claude shared chats at `https://claude.ai/chat/...`.
///
/// Attempts to recover role/text pairs from JSON-like structures embedded in
/// the page before falling back to generic HTML heuristics.
class ClaudeChatParser implements ChatParser {
  final GenericChatParser _fallback = GenericChatParser();

  @override
  Future<List<ImportedMessage>> parse(String url, String html) async {
    final messages = <ImportedMessage>[];

    // Claude often serialises messages with a role and content/text field in
    // embedded JSON. This regex aims to pick up those fragments.
    final roleTextRegex = RegExp(
      r'"role"\s*:\s*"(user|assistant)"[^{\]]+?"(?:text|content)"\s*:\s*"(.*?)"',
      caseSensitive: false,
      dotAll: true,
    );

    final matches = roleTextRegex.allMatches(html).toList();
    if (matches.isNotEmpty) {
      var index = 0;
      for (final m in matches) {
        if (m.groupCount < 2) continue;
        final rawRole = (m.group(1) ?? 'user').toLowerCase();
        final role = rawRole == 'assistant'
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
            id: 'claude_json_$index',
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

    return _fallback.parse(url, html);
  }
}
