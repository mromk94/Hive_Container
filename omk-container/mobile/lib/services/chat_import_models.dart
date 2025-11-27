/// Shared models and interfaces for importing AI chat conversations
/// from external providers like ChatGPT, Gemini, Claude, etc.

/// Role for imported transcript messages.
/// Kept deliberately small: only `user` and `assistant` are needed
/// for persona-building.
enum ImportedRole {
  user,
  assistant,
}

/// A single message inside an imported conversation transcript.
class ImportedMessage {
  ImportedMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.index,
    this.timestamp,
  });

  final String id;
  final ImportedRole role;
  final String text;
  final int index;
  final DateTime? timestamp;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'text': text,
        'index': index,
        'timestamp': timestamp?.millisecondsSinceEpoch,
      };

  factory ImportedMessage.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['role'] as String?) ?? 'user';
    final role = rawRole == 'assistant' ? ImportedRole.assistant : ImportedRole.user;
    return ImportedMessage(
      id: (json['id'] as String?) ?? '',
      role: role,
      text: (json['text'] as String?) ?? '',
      index: (json['index'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] is num
          ? DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as num).toInt())
          : null,
    );
  }
}

/// A normalized transcript extracted from a shared chat link.
class ImportedTranscript {
  ImportedTranscript({
    required this.sourceUrl,
    required this.providerId,
    required this.fetchedAt,
    required this.messages,
  });

  final String sourceUrl;
  final String providerId; // e.g. `openai`, `gemini`, `claude`, `generic`.
  final DateTime fetchedAt;
  final List<ImportedMessage> messages;
}

/// High-level source provider classification based on the share URL.
enum ChatProviderType {
  openai,
  gemini,
  claude,
  grok,
  huggingface,
  poe,
  perplexity,
  deepseek,
  copilot,
  generic,
}

/// Lightweight error type used by the importer layer.
class ChatImportException implements Exception {
  ChatImportException(this.message);

  final String message;

  @override
  String toString() => 'ChatImportException: $message';
}

/// Parser interface used by provider-specific implementations.
abstract class ChatParser {
  Future<List<ImportedMessage>> parse(String url, String html);
}

/// Shared helper to classify providers from URLs.
ChatProviderType detectProviderFromUrl(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('chat.openai.com') || lower.contains('chatgpt.com')) {
    return ChatProviderType.openai;
  }
  if (lower.contains('g.co/bard') || lower.contains('gemini.google.com') || lower.contains('g.co/gemini')) {
    return ChatProviderType.gemini;
  }
  if (lower.contains('grok.com')) {
    return ChatProviderType.grok;
  }
  if (lower.contains('claude.ai')) {
    return ChatProviderType.claude;
  }
  if (lower.contains('huggingface.co') && lower.contains('/chat')) {
    return ChatProviderType.huggingface;
  }
  if (lower.contains('poe.com')) {
    return ChatProviderType.poe;
  }
  if (lower.contains('perplexity.ai')) {
    return ChatProviderType.perplexity;
  }
  if (lower.contains('deepseek.com')) {
    return ChatProviderType.deepseek;
  }
  if (lower.contains('copilot.microsoft.com') || lower.contains('bing.com/chat')) {
    return ChatProviderType.copilot;
  }
  return ChatProviderType.generic;
}
