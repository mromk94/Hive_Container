import '../chat_import_models.dart';
import 'generic_parser.dart';

class PoeChatParser implements ChatParser {
  final GenericChatParser _fallback = GenericChatParser();

  @override
  Future<List<ImportedMessage>> parse(String url, String html) async {
    return _fallback.parse(url, html);
  }
}
