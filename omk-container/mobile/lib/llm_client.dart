import 'package:dio/dio.dart';

import 'consciousness_registry.dart';
import 'state.dart';
import 'local_light_model.dart';
import 'url_risk_model.dart';

abstract class LlmClient {
  Future<String> chat({
    required List<ChatMessage> history,
    required String userInput,
  });
}

String _buildHistoryPrompt(List<ChatMessage> history, String userInput) {
  final buffer = StringBuffer();
  final recent = history.length <= 10
      ? history
      : history.sublist(history.length - 10);
  for (final m in recent) {
    if (m.text.trim().isEmpty) continue;
    final role = m.role == 'assistant'
        ? 'Assistant'
        : m.role == 'system'
            ? 'System'
            : 'You';
    buffer.writeln('$role: ${m.text.trim()}');
  }
  buffer.writeln('You: ${userInput.trim()}');
  return buffer.toString();
}

class OpenAiLlmClient implements LlmClient {
  OpenAiLlmClient(this._dio, this._config);

  final Dio _dio;
  final ConsciousnessProviderConfig _config;

  @override
  Future<String> chat({
    required List<ChatMessage> history,
    required String userInput,
  }) async {
    final key = _config.apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw StateError('Missing OpenAI API key');
    }
    final model = _config.preferredModel ?? 'gpt-4.1-mini';
    final uri = 'https://api.openai.com/v1/chat/completions';
    final messages = [
      ...history.map((m) => {
            'role': m.role,
            'content': m.text,
          }),
      {
        'role': 'user',
        'content': userInput,
      },
    ];
    final resp = await _dio.post<Map<String, dynamic>>(
      uri,
      options: Options(
        headers: <String, String>{
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
      ),
      data: <String, dynamic>{
        'model': model,
        'messages': messages,
      },
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('Empty OpenAI response');
    }
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final msg = first['message'];
        if (msg is Map) {
          final content = msg['content'];
          if (content is String && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
      }
    }
    throw StateError('No content in OpenAI response');
  }
}

class GeminiLlmClient implements LlmClient {
  GeminiLlmClient(this._dio, this._config);

  final Dio _dio;
  final ConsciousnessProviderConfig _config;

  @override
  Future<String> chat({
    required List<ChatMessage> history,
    required String userInput,
  }) async {
    final key = _config.apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw StateError('Missing Gemini API key');
    }
    final model = _config.preferredModel ?? 'gemini-1.5-pro-latest';
    final base = 'https://generativelanguage.googleapis.com';
    final path = '/v1beta/models/$model:generateContent';
    final uri = '$base$path?key=$key';
    final contents = <Map<String, dynamic>>[
      {
        'parts': [
          {
            'text': _buildHistoryPrompt(history, userInput),
          },
        ],
      },
    ];
    final resp = await _dio.post<Map<String, dynamic>>(
      uri,
      options: Options(
        headers: const <String, String>{
          'Content-Type': 'application/json',
        },
      ),
      data: <String, dynamic>{
        'contents': contents,
      },
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('Empty Gemini response');
    }
    final candidates = data['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final first = candidates.first;
      if (first is Map) {
        final cContents = first['content'];
        if (cContents is Map) {
          final parts = cContents['parts'];
          if (parts is List && parts.isNotEmpty) {
            final p = parts.first;
            if (p is Map) {
              final text = p['text'];
              if (text is String && text.trim().isNotEmpty) {
                return text.trim();
              }
            }
          }
        }
      }
    }
    throw StateError('No content in Gemini response');
  }
}

class ClaudeLlmClient implements LlmClient {
  ClaudeLlmClient(this._dio, this._config);

  final Dio _dio;
  final ConsciousnessProviderConfig _config;

  @override
  Future<String> chat({
    required List<ChatMessage> history,
    required String userInput,
  }) async {
    final key = _config.apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw StateError('Missing Claude API key');
    }
    final model = _config.preferredModel ?? 'claude-3.5-sonnet';
    final uri = 'https://api.anthropic.com/v1/messages';
    final messages = [
      ...history.map((m) => {
            'role': m.role == 'assistant' ? 'assistant' : 'user',
            'content': m.text,
          }),
      {
        'role': 'user',
        'content': userInput,
      },
    ];
    final resp = await _dio.post<Map<String, dynamic>>(
      uri,
      options: Options(
        headers: <String, String>{
          'x-api-key': key,
          'content-type': 'application/json',
          'anthropic-version': '2023-06-01',
        },
      ),
      data: <String, dynamic>{
        'model': model,
        'max_tokens': 512,
        'messages': messages,
      },
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('Empty Claude response');
    }
    final content = data['content'];
    if (content is List && content.isNotEmpty) {
      final first = content.first;
      if (first is Map) {
        final text = first['text'];
        if (text is String && text.trim().isNotEmpty) {
          return text.trim();
        }
      }
    }
    throw StateError('No content in Claude response');
  }
}

class GrokLlmClient implements LlmClient {
  GrokLlmClient(this._dio, this._config);

  final Dio _dio;
  final ConsciousnessProviderConfig _config;

  @override
  Future<String> chat({
    required List<ChatMessage> history,
    required String userInput,
  }) async {
    final key = _config.apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw StateError('Missing Grok API key');
    }
    final base = _config.baseUrl?.trim().isNotEmpty == true
        ? _config.baseUrl!.trim()
        : 'https://api.x.ai';
    final model = _config.preferredModel ?? 'grok-beta';
    final uri = '$base/v1/chat/completions';
    final messages = [
      ...history.map((m) => {
            'role': m.role,
            'content': m.text,
          }),
      {
        'role': 'user',
        'content': userInput,
      },
    ];
    final resp = await _dio.post<Map<String, dynamic>>(
      uri,
      options: Options(
        headers: <String, String>{
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
      ),
      data: <String, dynamic>{
        'model': model,
        'messages': messages,
      },
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('Empty Grok response');
    }
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final msg = first['message'];
        if (msg is Map) {
          final content = msg['content'];
          if (content is String && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
      }
    }
    throw StateError('No content in Grok response');
  }
}

class DeepseekLlmClient implements LlmClient {
  DeepseekLlmClient(this._dio, this._config);

  final Dio _dio;
  final ConsciousnessProviderConfig _config;

  @override
  Future<String> chat({
    required List<ChatMessage> history,
    required String userInput,
  }) async {
    final key = _config.apiKey?.trim();
    if (key == null || key.isEmpty) {
      throw StateError('Missing DeepSeek API key');
    }
    final model = _config.preferredModel ?? 'deepseek-chat';
    final uri = 'https://api.deepseek.com/v1/chat/completions';
    final messages = [
      ...history.map((m) => {
            'role': m.role,
            'content': m.text,
          }),
      {
        'role': 'user',
        'content': userInput,
      },
    ];
    final resp = await _dio.post<Map<String, dynamic>>(
      uri,
      options: Options(
        headers: <String, String>{
          'Authorization': 'Bearer $key',
          'Content-Type': 'application/json',
        },
      ),
      data: <String, dynamic>{
        'model': model,
        'messages': messages,
      },
    );
    final data = resp.data;
    if (data == null) {
      throw StateError('Empty DeepSeek response');
    }
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map) {
        final msg = first['message'];
        if (msg is Map) {
          final content = msg['content'];
          if (content is String && content.trim().isNotEmpty) {
            return content.trim();
          }
        }
      }
    }
    throw StateError('No content in DeepSeek response');
  }
}

class LocalStubLlmClient implements LlmClient {
  LocalStubLlmClient(this._config)
      : _model = HeuristicLightModel(UrlRiskModel.instance);

  final ConsciousnessProviderConfig _config;
  final LocalLightModel _model;

  @override
  Future<String> chat({
    required List<ChatMessage> history,
    required String userInput,
  }) async {
    // Build a compact local context: last few user + assistant turns.
    final buffer = StringBuffer();
    final recent = history.length <= 8
        ? history
        : history.sublist(history.length - 8);
    for (final m in recent) {
      if (m.text.trim().isEmpty) continue;
      final role = m.role == 'assistant' ? 'Assistant' : 'You';
      buffer.writeln('$role: ${m.text.trim()}');
    }
    buffer.writeln('You: ${userInput.trim()}');

    final summary = await _model.summarizeShort(buffer.toString());
    if (summary.trim().isEmpty) {
      return '[Local] (no content yet)';
    }
    return summary.trim();
  }
}

class LlmClientFactory {
  static LlmClient? fromConfig(
    ConsciousnessProviderId id,
    ConsciousnessProviderConfig cfg,
    Dio dio,
  ) {
    switch (id) {
      case ConsciousnessProviderId.openai:
        return OpenAiLlmClient(dio, cfg);
      case ConsciousnessProviderId.gemini:
        return GeminiLlmClient(dio, cfg);
      case ConsciousnessProviderId.claude:
        return ClaudeLlmClient(dio, cfg);
      case ConsciousnessProviderId.grok:
        return GrokLlmClient(dio, cfg);
      case ConsciousnessProviderId.deepseek:
        return DeepseekLlmClient(dio, cfg);
      case ConsciousnessProviderId.local:
        return LocalStubLlmClient(cfg);
    }
  }
}
