import '../chat_import_models.dart';
import 'generic_parser.dart';

/// Parser for Grok shared chats at `https://grok.com/share/...`.
///
/// In this build we delegate to the generic HTML-based heuristics while
/// keeping a dedicated hook for future Grok-specific parsing rules.
class GrokChatParser implements ChatParser {
  final GenericChatParser _fallback = GenericChatParser();

  @override
  Future<List<ImportedMessage>> parse(String url, String html) async {
    return _fallback.parse(url, html);
  }
}
