# Backend Privacy & Auth Design

## API Keys

- Each OMK client (app/installation) receives an API key.
- Clients send it via `X-OMK-API-Key` header.
- Keys are scoped to tenant and environment (prod / staging).
- Rotation supported via admin panel or CLI.

## JWT Access Tokens

- Short-lived JWTs (e.g. 5–15 minutes) for user-level actions.
- Signed with ES256 or HS256 (rotated keys).
- Sent via `Authorization: Bearer <token>`.
- Claims:
  - `sub` — user or device ID (hashed).
  - `scope` — allowed operations (e.g. `analyze`, `escalate`, `admin`).
  - `exp`, `iat` — expiry and issued-at.

## End-to-End Encryption for Sensitive Fields

- Sensitive context fields (e.g. text snippets, user notes) can be
  encrypted on-device before being sent to Hive Bridge.
- Each tenant has a public encryption key; private key lives in a
  dedicated secure service.
- Clients encrypt payload sections (e.g. `snapshot.text_snippets`) using
  hybrid crypto (X25519 + XChaCha20-Poly1305).
- Hive Bridge stores the ciphertext and operates only on metadata
  (hashes, scores). Decryption is only performed in a tightly-controlled
  analysis environment if needed.

## Audit Logs

- Every `/analyze` and `/escalate` call writes an audit record:
  - timestamp
  - hashed user/device id
  - API key id
  - endpoint and status
  - verdict and risk score (no raw PII)
- Logs are immutable (append-only) and retained under a configurable
  retention policy.

## Deletion Endpoints

- `DELETE /incidents/:id`
  - Marks incident + associated context as deleted.
  - Actual deletion run by a background job, respecting legal hold rules.

- `DELETE /user-data`
  - Accepts an identifier (hashed) and deletes all records associated
    with that user/device, except where retention is mandated.

## Dev / Test Mode

- In development, auth checks can run in a permissive mode where missing
  API keys/JWTs generate warnings instead of rejections.
- This is controlled via environment flags and must be disabled in prod.
