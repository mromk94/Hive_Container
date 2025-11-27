import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import 'node_identity.dart';

/// Lightweight runtime representation of a mesh session.
class MeshSession {
  MeshSession({
    required this.sessionId,
    required this.nodeId,
    required this.createdAtMillis,
  });

  final String sessionId;
  final String nodeId;
  final int createdAtMillis;
}

/// Helper for constructing logical L-Mesh handshake frames.
///
/// This does NOT implement real public-key crypto yet; it only
/// establishes a pseudo-random session identifier and a structured
/// hello frame that matches L-MESH-HANDSHAKE.md.
class MeshHandshake {
  MeshHandshake._();

  static MeshSession? _current;

  static MeshSession? get current => _current;

  /// Ensure there is a current session for the given node.
  static Future<MeshSession> ensureSession(NodeIdentity node) async {
    if (_current != null) return _current!;
    final now = DateTime.now().millisecondsSinceEpoch;
    final salt = '$now-${node.nodeId.hashCode}';
    final h = crypto.sha256.convert(utf8.encode('${node.nodeId}::$salt')).toString();
    final sessionId = 'sess-${h.substring(0, 16)}';
    _current = MeshSession(
      sessionId: sessionId,
      nodeId: node.nodeId,
      createdAtMillis: now,
    );
    return _current!;
  }

  /// Build a logical "omk_hello" frame for this session.
  ///
  /// Real implementations will attach a public key and signature; for
  /// now we only provide a stable shape that transports can forward.
  static Map<String, Object?> buildHelloFrame(MeshSession session) {
    return <String, Object?>{
      'type': 'omk_hello',
      'node_id': session.nodeId,
      'session_id': session.sessionId,
      'capabilities': <String>['context_mesh', 'light_llm'],
      'ts': session.createdAtMillis,
      // Placeholders until native crypto is wired.
      'pubkey': null,
      'sig': null,
    };
  }
}
