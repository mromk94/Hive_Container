import 'package:dio/dio.dart';

import 'state.dart';
import 'services/omk_wallet_service.dart';
import 'llm_client.dart';
import 'consciousness_registry.dart';

class InsufficientOmkException implements Exception {
  InsufficientOmkException(this.estimatedCostOmk);
  final String estimatedCostOmk;

  @override
  String toString() => 'InsufficientOmkException(cost=$estimatedCostOmk)';
}

class OmkLlmClient {
  OmkLlmClient({
    required Dio dio,
    required OmkWalletService wallet,
    required String queenBaseUrl,
  })  : _dio = dio,
        _wallet = wallet,
        _queenBaseUrl = queenBaseUrl.trim().isEmpty
            ? 'https://omk-queen-ai-475745165557.us-central1.run.app'
            : queenBaseUrl.trim();

  final Dio _dio;
  final OmkWalletService _wallet;
  final String _queenBaseUrl;

  static const Map<String, double> _costPerKTokens = <String, double>{
    'gpt': 0.01,
    'claude': 0.011,
    'gemini': 0.009,
    'grok': 0.009,
    'deepseek': 0.006,
    'local': 0.0,
  };

  Future<String> sendMessage({
    required String modelId,
    required List<ChatMessage> messages,
    String? personaPackId,
  }) async {
    // Local/light models bypass Queen + wallet and reuse the existing
    // LocalStubLlmClient so that offline mode keeps working.
    if (modelId == 'local') {
      final localClient = LocalStubLlmClient(
        ConsciousnessProviderConfig(),
      );
      final history = messages;
      final lastUser = history.lastWhere(
        (m) => m.role == 'user',
        orElse: () => ChatMessage(role: 'user', text: ''),
      );
      return localClient.chat(history: history, userInput: lastUser.text);
    }

    final estTokens = _estimateTokens(messages);
    final costPerK = _costPerKTokens[modelId] ?? 0.01;
    final cost = (estTokens / 1000.0) * costPerK;
    final costStr = cost.toStringAsFixed(4);

    final spendOk = await _wallet.spendOmk(
      amountOmk: costStr,
      reason: 'llm_call:$modelId',
    );
    if (!spendOk) {
      throw InsufficientOmkException(costStr);
    }

    final uri = '$_queenBaseUrl/llm/generate';
    final body = <String, dynamic>{
      'model': modelId,
      'messages': messages
          .map((m) => <String, dynamic>{'role': m.role, 'text': m.text})
          .toList(growable: false),
      if (personaPackId != null) 'personaPackId': personaPackId,
    };

    final resp = await _dio.post<Map<String, dynamic>>(uri, data: body);
    final data = resp.data ?? <String, dynamic>{};
    final response = data['response'];

    if (response is String) {
      return response.trim();
    }
    if (response is Map<String, dynamic>) {
      final text = response['text'] ?? response['content'];
      if (text is String && text.trim().isNotEmpty) {
        return text.trim();
      }
    }

    throw StateError('No usable text in Queen LLM response');
  }

  int _estimateTokens(List<ChatMessage> messages) {
    var chars = 0;
    for (final m in messages) {
      chars += m.text.length;
    }
    if (chars == 0) return 64;
    final est = (chars / 4).round();
    if (est < 64) return 64;
    if (est > 4000) return 4000;
    return est;
  }
}
