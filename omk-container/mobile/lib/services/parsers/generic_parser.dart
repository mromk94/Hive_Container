import '../chat_import_models.dart';

/// Fallback parser that uses very simple heuristics to recover a conversation
/// from arbitrary HTML. It is intentionally conservative and only aims to
/// produce a rough user/assistant alternation so the persona builder has
/// something to work with.
class GenericChatParser implements ChatParser {
  @override
  Future<List<ImportedMessage>> parse(String url, String html) async {
    if (html.trim().isEmpty) {
      return <ImportedMessage>[];
    }

    // Replace common block-level tags with line breaks and strip all other
    // tags. This is not a full HTML parser but keeps dependencies small.
    var text = html
        .replaceAll('<br>', '\n')
        .replaceAll('<br/>', '\n')
        .replaceAll('<br />', '\n')
        .replaceAll('<p', '\n<p');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');

    // Collapse whitespace and split into coarse message-sized chunks.
    text = text.replaceAll('\r', '');
    final chunks = text
        .split(RegExp(r'\n{2,}'))
        .map((c) => c.trim())
        .where((c) => c.isNotEmpty)
        .toList();

    if (chunks.isEmpty) {
      return <ImportedMessage>[];
    }

    final messages = <ImportedMessage>[];
    var role = ImportedRole.user;
    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      messages.add(ImportedMessage(
        id: 'm$i',
        role: role,
        text: chunk,
        index: i,
      ));
      // Alternate roles so the transcript roughly looks like a dialogue.
      role = role == ImportedRole.user ? ImportedRole.assistant : ImportedRole.user;
      if (messages.length >= 40) {
        break;
      }
    }
    return messages;
  }
}
