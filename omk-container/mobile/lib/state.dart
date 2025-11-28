import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analyze_page_action.dart';
import 'connectivity_advisor.dart';
import 'connectivity_mode.dart';
import 'security_checkpoint.dart';
import 'chat_store.dart';
import 'consciousness_engine.dart';
import 'omk_llm_client.dart';
import 'local_light_model.dart';
import 'url_risk_model.dart';
import 'vpn_channel.dart';

class ChatMessage {
  ChatMessage({required this.role, required this.text});

  final String role; // 'user' | 'assistant' | 'system'
  final String text;

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: (json['role'] as String?) ?? 'user',
      text: (json['text'] as String?) ?? '',
    );
  }
}

class MiniChatController extends StateNotifier<List<ChatMessage>> {
  MiniChatController() : super(const []) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final raw = await ChatStore.load();
    if (raw.isEmpty) return;
    final loaded = raw
        .map((e) => ChatMessage.fromJson(e))
        .where((m) {
          final text = m.text.trim();
          if (text.isEmpty) return false;
          // Strip any legacy "stub" messages from older builds so
          // they do not pollute the current chat experience.
          final lower = text.toLowerCase();
          if (lower.contains('stub omk') || lower.startsWith('(stub')) {
            return false;
          }
          return true;
        })
        .toList();
    if (loaded.isNotEmpty) {
      state = loaded;
    }
  }

  /// Merge any newer messages from the shared store into local state.
  Future<void> syncFromStore() async {
    final raw = await ChatStore.load();
    if (raw.isEmpty) return;
    final loaded = raw
        .map((e) => ChatMessage.fromJson(e))
        .where((m) {
          final text = m.text.trim();
          if (text.isEmpty) return false;
          final lower = text.toLowerCase();
          if (lower.contains('stub omk') || lower.startsWith('(stub')) {
            return false;
          }
          return true;
        })
        .toList();
    state = loaded;
  }

  Future<void> _persist() async {
    final data = state.map((m) => m.toJson()).toList(growable: false);
    await ChatStore.save(data);
  }

  void sendUserMessage(String text) {
    if (text.trim().isEmpty) return;
    state = [
      ...state,
      ChatMessage(role: 'user', text: text.trim()),
    ];
    _persist();
  }

  Future<void> sendWithConsciousness(String text) async {
    if (text.trim().isEmpty) return;
    state = [
      ...state,
      ChatMessage(role: 'user', text: text.trim()),
    ];
    await _persist();
    try {
      final engine = await ConsciousnessEngine.load();
      final reply = await engine.generateReply(state, text);
      if (reply.trim().isEmpty) return;
      state = [
        ...state,
        ChatMessage(role: 'assistant', text: reply.trim()),
      ];
      await _persist();
    } on InsufficientOmkException {
      rethrow;
    } catch (_) {}
  }

  void addAssistantMessage(String text) {
    state = [
      ...state,
      ChatMessage(role: 'assistant', text: text.trim()),
    ];
    _persist();
  }

  Future<void> runQuickAction(String action) async {
    String label;
    switch (action) {
      case 'analyze_page':
        addAssistantMessage('Analyzing current context...');
        try {
          final decision = await analyzeCurrentContext(state);
          final checkpoint = SecurityCheckpoint.evaluate(decision);
          final mode = ConnectivityAdvisor.currentMode();
          final modeText = switch (mode) {
            ConnectivityMode.cloud => 'cloud',
            ConnectivityMode.localMesh => 'mesh-local',
            ConnectivityMode.offline => 'offline-local',
          };
          final levelText = switch (checkpoint.level) {
            SecurityAlertLevel.alert => 'ALERT',
            SecurityAlertLevel.warn => 'WARN',
            SecurityAlertLevel.safe => 'SAFE',
          };
          label =
              'Decision: ${decision.verdict} • score=${checkpoint.score} [$levelText]\n'
              'Mode: $modeText\n'
              'Reasons: ${checkpoint.reasons.join('; ')}\n'
              'Path: ${decision.path.join(' → ')}';
        } catch (_) {
          label = 'Analyze failed in this debug build.';
        }
        break;
      case 'summarize':
        try {
          final text = state
              .map((m) => '${m.role}: ${m.text}')
              .join('\n')
              .trim();
          if (text.isEmpty) {
            label = 'Not enough activity yet to summarize.';
          } else {
            final light = HeuristicLightModel(UrlRiskModel.instance);
            final summary = await light.summarizeShort(text);
            label = summary.isEmpty
                ? 'Summary is empty for this context.'
                : summary;
          }
        } catch (_) {
          label = 'Summarize failed in this build.';
        }
        break;
      case 'guard_me':
        try {
          await OmkVpnChannel.startVpn();
          label =
              'Guard Me VPN is now watching this device using local inspection. OMK will flag risky pages as you browse.';
        } catch (_) {
          label = 'Guard Me could not start the VPN guard in this build.';
        }
        break;
      case 'report_phishing':
        label = 'Marked as suspicious. This will be escalated in a real build.';
        break;
      default:
        label = 'Action queued (mock).';
    }
    addAssistantMessage(label);
    await _persist();
  }

  void clearHistory() {
    state = const [];
    _persist();
  }
}

bool onboardingCompletedBootstrap = false;

final miniChatProvider =
    StateNotifierProvider<MiniChatController, List<ChatMessage>>(
  (ref) => MiniChatController(),
);

final floatingEnabledProvider = StateProvider<bool>((ref) => true);
final bubbleExpandedProvider = StateProvider<bool>((ref) => false);
final onboardingCompletedProvider =
    StateProvider<bool>((ref) => onboardingCompletedBootstrap);
final assistantOpenProvider = StateProvider<bool>((ref) => false);

final navIndexProvider = StateProvider<int>((ref) => 0);
final omkPowerOnProvider = StateProvider<bool>((ref) => false);
final assistantDarkModeProvider = StateProvider<bool>((ref) => true);

final selectedModelProvider = StateProvider<String>((ref) => 'gemini');
final securityTtlMinutesProvider = StateProvider<int>((ref) => 30);

final overlayPermissionGrantedProvider = StateProvider<bool>((ref) => false);
final vpnPermissionGrantedProvider = StateProvider<bool>((ref) => false);
final accessibilityPermissionGrantedProvider =
    StateProvider<bool>((ref) => false);
final screenshotPermissionGrantedProvider =
    StateProvider<bool>((ref) => false);
final microphonePermissionGrantedProvider =
    StateProvider<bool>((ref) => false);

ThemeData omkTheme(bool isDark) {
  const seed = Color(0xFFD4AF37);
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: isDark ? Brightness.dark : Brightness.light,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor:
        isDark ? const Color(0xFF050509) : scheme.background,
    useMaterial3: true,
  );
}
