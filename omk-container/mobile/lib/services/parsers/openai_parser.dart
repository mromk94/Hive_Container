import 'dart:convert';

import '../chat_import_models.dart';

/// Parser for ChatGPT shared chats at `https://chat.openai.com/share/...`.
///
/// This implementation extracts messages from the Next.js `__NEXT_DATA__`
/// payload embedded in the page. It only trusts that single JSON blob and
/// ignores all other scripts/HTML, returning an empty list if no usable
/// messages are found so the caller can fall back gracefully.
class OpenAiChatParser implements ChatParser {
  @override
  Future<List<ImportedMessage>> parse(String url, String html) async {
    return _parseFromNextData(html);
  }
  List<ImportedMessage> _parseFromNextData(String html) {
    final out = <ImportedMessage>[];
    final trimmed = html.trim();
    if (trimmed.isEmpty) return out;

    final nextDataRegex = RegExp(
      r'<script[^>]*id="__NEXT_DATA__"[^>]*>(.*?)<\/script>',
      caseSensitive: false,
      dotAll: true,
    );
    final match = nextDataRegex.firstMatch(trimmed);
    if (match == null) {
      return out;
    }

    final body = match.group(1) ?? '';
    dynamic root;
    try {
      root = jsonDecode(body);
    } catch (_) {
      return out;
    }

    String _extractText(dynamic content) {
      // Content can be a simple string, a list of text chunks, or a ChatGPT
      // style object with `parts: [{text: ...}]`.
      if (content is String) return content;

      if (content is List) {
        final parts = <String>[];
        for (final c in content) {
          if (c is String) {
            parts.add(c);
          } else if (c is Map && c['text'] is String) {
            parts.add(c['text'] as String);
          }
        }
        return parts.join('\n');
      }

      if (content is Map) {
        if (content['text'] is String) {
          return content['text'] as String;
        }
        if (content['parts'] is List) {
          return _extractText(content['parts']);
        }
        if (content['content'] != null) {
          return _extractText(content['content']);
        }
      }

      return '';
    }

    var index = 0;
    void visit(dynamic node) {
      if (node is Map) {
        // Case 1: direct role/content pair.
        if (node.containsKey('role') && node.containsKey('content')) {
          final rawRole = (node['role'] ?? 'user').toString().toLowerCase();
          final role = rawRole == 'assistant'
              ? ImportedRole.assistant
              : ImportedRole.user;
          final text = _extractText(node['content']).trim();
          if (text.isNotEmpty) {
            out.add(ImportedMessage(
              id: 'gpt_next_$index',
              role: role,
              text: text,
              index: index,
            ));
            index++;
            if (out.length >= 80) {
              return;
            }
          }
        }

        // Case 2: ChatGPT-style message object with `author.role` and
        // `content` containing `parts`.
        if (node.containsKey('author') && node.containsKey('content')) {
          final author = node['author'];
          if (author is Map && author['role'] is String) {
            final rawRole = (author['role'] as String).toLowerCase();
            final role = rawRole == 'assistant'
                ? ImportedRole.assistant
                : ImportedRole.user;
            final text = _extractText(node['content']).trim();
            if (text.isNotEmpty) {
              out.add(ImportedMessage(
                id: 'gpt_next_$index',
                role: role,
                text: text,
                index: index,
              ));
              index++;
              if (out.length >= 80) {
                return;
              }
            }
          }
        }

        for (final v in node.values) {
          if (out.length >= 80) return;
          visit(v);
        }
      } else if (node is List) {
        for (final v in node) {
          if (out.length >= 80) return;
          visit(v);
        }
      }
    }

    visit(root);
    return out;
  }
}
