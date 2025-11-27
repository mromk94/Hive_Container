import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import 'context_channel.dart';
import 'state.dart';

/// Semantic packet passed to higher-level reasoning / LLM layers.
class SemanticPacket {
  SemanticPacket({
    required this.timestampMillis,
    required this.source,
    required this.intentConfidence,
    required this.actionType,
    required this.summaryText,
  });

  /// Unix timestamp in milliseconds.
  final int timestampMillis;

  /// Source of this packet, e.g. "mini_chat", "background_scan".
  final String source;

  /// Heuristic confidence [0,1] that the user intends this action.
  final double intentConfidence;

  /// Action type, e.g. "analyze_page", "summarize", "report_phishing".
  final String actionType;

  /// Short human-readable summary of the situation.
  final String summaryText;

  Map<String, Object?> toJson() => <String, Object?>{
        'ts': timestampMillis,
        'source': source,
        'intent_confidence': intentConfidence,
        'action_type': actionType,
        'summary_text': summaryText,
      };
}

/// Context Normalization Layer (CNL).
///
/// Converts raw CCE + chat messages into compact semantic packets and
/// avoids re-emitting identical packets.
class ContextNormalizationLayer {
  ContextNormalizationLayer._();

  static String? _lastFingerprint;

  static SemanticPacket? buildIfChanged({
    required ContextSnapshot cce,
    required List<ChatMessage> messages,
    required String source,
    required String actionType,
  }) {
    final packet = _buildPacket(
      cce: cce,
      messages: messages,
      source: source,
      actionType: actionType,
    );
    final fp = _fingerprint(packet);
    if (fp == _lastFingerprint) {
      return null; // unchanged, caller can skip sending
    }
    _lastFingerprint = fp;
    return packet;
  }

  static SemanticPacket _buildPacket({
    required ContextSnapshot cce,
    required List<ChatMessage> messages,
    required String source,
    required String actionType,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Last user message (if any) is usually the clearest expression of intent.
    final lastUser = messages.reversed.firstWhere(
      (m) => m.role == 'user',
      orElse: () => ChatMessage(role: 'user', text: ''),
    );

    // Build a short summary from app label + a representative snippet.
    final app = cce.appLabel ?? cce.appPackage ?? 'this app';
    final snippet = (cce.textSnippets + [lastUser.text])
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .take(3)
        .join(' • ');

    final summary = snippet.isEmpty
        ? 'Analyze activity in $app'
        : 'Analyze activity in $app: $snippet';

    // Simple heuristic for intent confidence.
    double confidence = 0.5;
    final lower = lastUser.text.toLowerCase();
    if (lower.contains('phish') || lower.contains('scam')) confidence = 0.9;
    if (lower.contains('safe') || lower.contains('secure')) confidence = 0.8;
    if (lastUser.text.trim().isEmpty && cce.textSnippets.isEmpty) confidence = 0.3;

    return SemanticPacket(
      timestampMillis: now,
      source: source,
      intentConfidence: confidence.clamp(0.0, 1.0),
      actionType: actionType,
      summaryText: summary.length > 240 ? summary.substring(0, 240) : summary,
    );
  }

  static String _fingerprint(SemanticPacket packet) {
    final json = jsonEncode(packet.toJson());
    return crypto.sha256.convert(utf8.encode(json)).toString();
  }
}
