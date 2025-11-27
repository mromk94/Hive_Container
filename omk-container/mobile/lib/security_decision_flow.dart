import 'dart:developer' as dev;

import 'package:dio/dio.dart';

import 'bloom_client.dart';
import 'connectivity_advisor.dart';
import 'connectivity_mode.dart';
import 'coop_cache.dart';
import 'larry_threat_analyzer.dart';
import 'local_light_model.dart';
import 'memory_matcher.dart';
import 'mesh_consensus.dart';
import 'mesh_persistence.dart';
import 'network_telemetry.dart';
import 'privacy_sanitizer.dart' as pii;
import 'security_memory_db.dart';
import 'url_risk_model.dart';

/// Decision result for a given page/context.
class SecurityDecision {
  SecurityDecision({
    required this.verdict,
    required this.riskScore,
    required this.path,
  });

  final String verdict; // allow | block | review
  final double riskScore;
  final List<String> path; // instrumentation of which steps fired
}

/// Compact input for decision flow (aligned with COMPACT-CONTEXT-SNAPSHOT).
class SecurityContextInput {
  SecurityContextInput({
    required this.urlHash,
    required this.host,
    this.certSummary,
    this.textSnippets = const [],
    this.screenshotHash,
    this.riskFeatures,
  });

  final String urlHash;
  final String host;
  final Map<String, Object?>? certSummary;
  final List<String> textSnippets;
  final String? screenshotHash;
   final UrlRiskFeatures? riskFeatures;
}

class SecurityDecisionEngine {
  SecurityDecisionEngine({required Dio dio})
      : _dio = dio,
        _bloom = BloomClient(dio);

  final Dio _dio;
  final BloomClient _bloom;

  Future<SecurityDecision> decide(SecurityContextInput input) async {
    final path = <String>[];

    // 1) Bloom filter check
    await _bloom.sync();
    if (_bloom.mayContainHost(input.host)) {
      path.add('bloom_hit');
    } else {
      path.add('bloom_miss');
    }

    // 2) security_memory lookup (exact)
    final db = await SecurityMemoryDb.open();
    await db.cleanupExpired();
    final cached = await db.getByUrlHash(input.urlHash);
    if (cached != null) {
      path.add('cache_hit:${cached.verdict}');
      dev.log('SecurityDecision cache hit', name: 'omk.security', error: cached.verdict);
      return SecurityDecision(
        verdict: cached.verdict,
        riskScore: cached.riskScore,
        path: path,
      );
    }
    path.add('cache_miss');

    // 2b) Fuzzy match against recent similar contexts to avoid redundant calls.
    final similar = await MemoryMatcher.findSimilar(
      urlHash: input.urlHash,
      host: input.host,
      textSnippets: input.textSnippets,
    );
    if (similar != null) {
      path.add('fuzzy_hit:${similar.entry.verdict}@${similar.similarity.toStringAsFixed(2)}');
      return SecurityDecision(
        verdict: similar.entry.verdict,
        riskScore: similar.entry.riskScore,
        path: path,
      );
    }

    // 3) On-device classifier (Larry-State threat analysis)
    // Prefer TFLite UrlRiskModel when features + model are available.
    // When offline, delegate to LarryThreatAnalyzer/LocalLightModel.
    double localScore;
    final mode = ConnectivityAdvisor.currentMode();
    if (input.riskFeatures != null && UrlRiskModel.instance.isReady) {
      if (mode == ConnectivityMode.offline) {
        final analyzer = LarryThreatAnalyzer(
          HeuristicLightModel(UrlRiskModel.instance),
          UrlRiskModel.instance,
        );
        final score = await analyzer.offlineUrlRisk(input.riskFeatures!);
        if (score != null) {
          localScore = score;
          path.add('offline_light_model:${localScore.toStringAsFixed(2)}');
        } else {
          localScore = _localRisk(input);
          path.add('offline_light_fallback:${localScore.toStringAsFixed(2)}');
        }
      } else {
        final score = await UrlRiskModel.instance.predict(input.riskFeatures!);
        if (score != null) {
          localScore = score;
          path.add('model_classifier:${localScore.toStringAsFixed(2)}');
        } else {
          localScore = _localRisk(input);
          path.add('local_classifier_fallback:${localScore.toStringAsFixed(2)}');
        }
      }
    } else {
      localScore = _localRisk(input);
      path.add('local_classifier:${localScore.toStringAsFixed(2)}');
    }

    if (localScore < 0.2 && !_bloom.mayContainHost(input.host)) {
      // Low risk, no bloom hit: allow and cache locally.
      await db.upsertFromSnapshot(
        urlHash: input.urlHash,
        host: input.host,
        riskScore: localScore,
        verdict: 'allow',
        source: 'classifier',
        ttl: const Duration(minutes: 30),
        snapshot: _snapshotForCache(input),
      );
      return SecurityDecision(verdict: 'allow', riskScore: localScore, path: path);
    }

    // 4) Escalate to Hive Bridge /analyze (mock server), but degrade
    // gracefully to localScore when offline or when the call fails.
    double risk = localScore;
    String verdict;
    String source = 'bridge';
    Duration ttl = const Duration(days: 30);

    final startMs = DateTime.now().millisecondsSinceEpoch;
    try {
      path.add('escalate_analyze');
      final res = await _dio.post('http://10.0.2.2:4317/analyze', data: {
        'text': input.textSnippets.map(pii.PrivacySanitizer.sanitize).join('\n'),
        'context': _snapshotForCache(input),
      });
      final data = res.data as Map<String, dynamic>;
      risk = (data['riskScore'] as num?)?.toDouble() ?? localScore;
      final dt = DateTime.now().millisecondsSinceEpoch - startMs;
      NetworkTelemetry.instance.recordCall(success: true, latencyMs: dt);
    } catch (e, st) {
      path.add('escalate_failed_offline');
      dev.log(
        'SecurityDecision escalate /analyze failed, using local score',
        name: 'omk.security',
        error: e,
        stackTrace: st,
      );
      final dt = DateTime.now().millisecondsSinceEpoch - startMs;
      NetworkTelemetry.instance.recordCall(success: false, latencyMs: dt);
      risk = localScore;
      source = 'classifier_offline';
      ttl = const Duration(minutes: 30);
    }

    verdict = risk >= 0.7
        ? 'block'
        : risk >= 0.4
            ? 'review'
            : 'allow';

    await db.upsertFromSnapshot(
      urlHash: input.urlHash,
      host: input.host,
      riskScore: risk,
      verdict: verdict,
      source: source,
      ttl: ttl,
      snapshot: _snapshotForCache(input),
    );
    await _recordCoopConsensusHint(input, verdict, risk, path);

    _applyUipGuardrails(input, verdict, risk, path);

    return SecurityDecision(verdict: verdict, riskScore: risk, path: path);
  }

  double _localRisk(SecurityContextInput input) {
    final text = input.textSnippets.join(' ').toLowerCase();
    var score = 0.0;
    if (text.contains('password') || text.contains('api key')) score += 0.3;
    if (text.contains('credit card')) score += 0.3;
    if (text.contains('login')) score += 0.1;
    return score.clamp(0.0, 1.0);
  }

  Map<String, Object?> _snapshotForCache(SecurityContextInput input) {
    return <String, Object?>{
      'url_hash': input.urlHash,
      'host': input.host,
      'cert_summary': input.certSummary,
      'top_text_snippets': input.textSnippets.map(pii.PrivacySanitizer.sanitize).toList(),
      'screenshot_hash': input.screenshotHash,
    };
  }

  Future<void> _recordCoopConsensusHint(
    SecurityContextInput input,
    String localVerdict,
    double localRisk,
    List<String> path,
  ) async {
    try {
      final snapshot = await MeshPersistenceHelper.loadSnapshot();
      if (snapshot.coopCache.isEmpty) {
        path.add('coop_consensus:none');
        return;
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final votes = <MeshVote>[];

      for (final entry in snapshot.coopCache) {
        if (entry.urlHash != input.urlHash || entry.isExpired) continue;
        final ageMs = (now - entry.createdAtMillis).clamp(0, 3600 * 1000);
        final freshness = 1.0 - (ageMs / (3600 * 1000));
        final weight = 1.0 + 0.5 * freshness;
        votes.add(
          MeshVote(
            key: entry.urlHash,
            value: entry.verdict,
            weight: weight,
            originNodeId: entry.originNodeId,
            createdAtMillis: entry.createdAtMillis,
          ),
        );
      }

      if (votes.isEmpty) {
        path.add('coop_consensus:none');
        return;
      }

      final result = MeshConsensus.decide(input.urlHash, votes);
      if (result == null) {
        path.add('coop_consensus:inconclusive');
        return;
      }

      path.add(
        'coop_consensus:${result.value}@${result.support.toStringAsFixed(2)}',
      );
    } catch (_) {
      // Best-effort only; ignore errors so coop consensus never breaks primary flow.
      path.add('coop_consensus:error');
    }
  }

  void _applyUipGuardrails(
    SecurityContextInput input,
    String verdict,
    double risk,
    List<String> path,
  ) {
    // Read-only UIP-style guardrails: log suspicious combinations of
    // verdict/risk without changing behavior.
    if (verdict == 'allow' && risk >= 0.8) {
      path.add('uip_guard:high_risk_allow');
      dev.log(
        'UIP guardrail: high-risk allow',
        name: 'omk.uip',
        error: <String, Object?>{
          'url_hash': input.urlHash,
          'host': input.host,
          'risk': risk,
          'verdict': verdict,
        },
      );
    } else if (verdict == 'block' && risk <= 0.2) {
      path.add('uip_guard:low_risk_block');
      dev.log(
        'UIP guardrail: low-risk block',
        name: 'omk.uip',
        error: <String, Object?>{
          'url_hash': input.urlHash,
          'host': input.host,
          'risk': risk,
          'verdict': verdict,
        },
      );
    }
  }
}
