# Compact Threat Sync Protocol

Daily sync between Hive Bridge and OMK clients.

## Goals

- Minimize bandwidth (tens of KB/day typical).
- Provide strong consistency guarantees via versioning and signatures.
- Ship three types of data:
  - Bloom filter for broad membership checks.
  - Domain hash set (high-risk hosts / URL hashes).
  - High-confidence malicious list with scores.

## Versioning

Each daily snapshot uses a monotonically increasing `version` string,
typically an ISO date: `YYYY-MM-DD`.

Clients call `/sync-bloom` with `lastVersion`; server responds with
`changed` and new payload or `changed=false`.

## Delta Format

Example response body:

```json
{
  "ok": true,
  "changed": true,
  "version": "2025-11-01",
  "bloom": {
    "version": "2025-11-01",
    "falsePositiveRate": 0.01,
    "estimatedEntries": 120000,
    "chunks": [
      "base64-bitset-chunk-0",
      "base64-bitset-chunk-1"
    ]
  },
  "domain_hashes": [
    "sha256(canonical_url_1)",
    "sha256(canonical_url_2)"
  ],
  "high_confidence": [
    { "host": "phish.example", "url_hash": "...", "score": 0.98, "source": "phish_tank" }
  ],
  "signature": {
    "alg": "ES256",
    "key_id": "omk-bridge-root-1",
    "value": "base64url-signature-over-body"
  }
}
```

## Signing

- Server signs the canonical JSON (without `signature`) using ES256.
- Clients verify against a pinned public key or key set.
- If signature fails, clients MUST discard the delta.

## REST Endpoints

- `POST /sync-bloom`
  - Request: `{ "lastVersion": "2025-10-31" }`.
  - Response: full delta as above; `changed=false` if no new data.

- `GET /threat/high-confidence`
  - Optional convenience endpoint returning only `high_confidence` list.

## Client Behavior

- Verify `signature` before updating local state.
- Replace previous bloom and domain_hashes on new version.
- Merge `high_confidence` into local security_memory with TTL.

## Privacy

- Deltas contain only **aggregated threat intelligence** (hashes, hosts),
  no per-user data.
