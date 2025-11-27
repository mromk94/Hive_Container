import 'package:dio/dio.dart';

import 'chat_import_models.dart';
import 'parsers/openai_parser.dart';
import 'parsers/gemini_parser.dart';
import 'parsers/claude_parser.dart';
import 'parsers/generic_parser.dart';
import 'parsers/grok_parser.dart';
import 'parsers/huggingface_parser.dart';
import 'parsers/poe_parser.dart';
import 'parsers/perplexity_parser.dart';
import 'parsers/deepseek_parser.dart';
import 'parsers/copilot_parser.dart';

/// Central entry point for turning a shared chat URL into an
/// `ImportedTranscript`.
///
/// In this build the service performs provider detection, attempts to fetch
/// the shared page content, and delegates to a provider-specific parser. If
/// anything fails, it falls back to a short synthetic transcript so that the
/// Import-by-Convo UI remains usable even without network access.
class ChatImporterService {
  ChatImporterService({Dio? dio}) : _dio = dio ?? Dio() {
    _parsers[ChatProviderType.openai] = OpenAiChatParser();
    _parsers[ChatProviderType.gemini] = GeminiChatParser();
    _parsers[ChatProviderType.claude] = ClaudeChatParser();
    _parsers[ChatProviderType.grok] = GrokChatParser();
    _parsers[ChatProviderType.huggingface] = HuggingFaceChatParser();
    _parsers[ChatProviderType.poe] = PoeChatParser();
    _parsers[ChatProviderType.perplexity] = PerplexityChatParser();
    _parsers[ChatProviderType.deepseek] = DeepSeekChatParser();
    _parsers[ChatProviderType.copilot] = CopilotChatParser();
    _parsers[ChatProviderType.generic] = GenericChatParser();
  }

  final Dio _dio;

  /// Registry for provider-specific parsers.
  final Map<ChatProviderType, ChatParser> _parsers = {};

  /// Detect which provider the given URL refers to.
  ChatProviderType detectProvider(String url) => detectProviderFromUrl(url);

  /// Fetch and parse a shared chat URL into an `ImportedTranscript`.
  ///
  /// Network and parsing errors are caught and converted into a small
  /// synthetic transcript so the caller can still move forward with persona
  /// creation.
  Future<ImportedTranscript> importFromUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      throw ChatImportException('Paste a shared chat link to continue.');
    }

    var normalized = trimmed;
    if (!normalized.startsWith('http')) {
      if (normalized.startsWith('chat.openai.com') || normalized.startsWith('chatgpt.com')) {
        normalized = 'https://$normalized';
      }
    }

    final provider = detectProvider(normalized);
    final now = DateTime.now();

    try {
      final resp = await _dio.get<String>(
        normalized,
        options: Options(responseType: ResponseType.plain),
      );
      final html = resp.data ?? '';
      if (html.trim().isEmpty) {
        throw ChatImportException('Empty response when fetching shared chat.');
      }
      final parser = _parsers[provider] ?? _parsers[ChatProviderType.generic];
      if (parser == null) {
        throw ChatImportException('No parser available for provider ${provider.name}.');
      }
      final messages = await parser.parse(normalized, html);
      if (messages.isEmpty) {
        throw ChatImportException('No messages could be parsed from this link.');
      }
      return ImportedTranscript(
        sourceUrl: normalized,
        providerId: provider.name,
        fetchedAt: now,
        messages: messages,
      );
    } catch (e) {
      assert(() {
        // Debug-only: surface failure reason during development.
        print('[ChatImporterService] importFromUrl failed for provider ${provider.name}: $e');
        return true;
      }());
      // Synthetic transcript: echo the provider and teach the user what the
      // later real import would do.
      final messages = <ImportedMessage>[
        ImportedMessage(
          id: 'm1',
          role: ImportedRole.user,
          index: 0,
          text:
              'OMK could not fully import this conversation in this build. '
              'This is a placeholder transcript for ${provider.name}.',
          timestamp: now,
        ),
        ImportedMessage(
          id: 'm2',
          role: ImportedRole.assistant,
          index: 1,
          text:
              'You can still continue to the persona step to create a local '
              'consciousness pack that stays on this device.',
          timestamp: now,
        ),
      ];

      return ImportedTranscript(
        sourceUrl: normalized,
        providerId: provider.name,
        fetchedAt: now,
        messages: messages,
      );
    }
  }
}
