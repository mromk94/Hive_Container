# L-Mesh Context Protocol

Defines how compact, privacy-preserving context is exchanged between OMK
nodes in a local mesh.

## Packet Shape

L-Mesh packets are built on top of the existing
COMPACT-CONTEXT-SNAPSHOT schema and always pass through the
PrivacySanitizer before transmission.

```jsonc
{
  "packet_id": "uuid-like",
  "origin_node_id": "node-abc",
  "created_at": 1712345678000,
  "ttl_ms": 30000,
  "hop_count": 0,
  "visibility": "local_only", // local_only | anon_cloud | tenant_scope
  "snapshot": { /* COMPACT-CONTEXT-SNAPSHOT body */ },
  "local_signals": {
    "bloom_hit": false,
    "local_risk_score": 0.21,
    "checkpoint_score": 35,
    "checkpoint_level": "SAFE"
  }
}
```

## Rules

- **Sanitization** — all text must pass through the on-device
  PrivacySanitizer before packaging.
- **TTL** — nodes MUST drop packets whose `created_at + ttl_ms` is in
  the past.
- **Hop Count** — increment `hop_count` on each forward; drop if exceeds
  a small limit (e.g., 3) to avoid loops.
- **Visibility**:
  - `local_only` — never forwarded to cloud.
  - `anon_cloud` — may be aggregated to Hive Bridge, with node_id
    stripped or pseudonymized.
  - `tenant_scope` — only forwarded to the users own cloud account.
