# L-Mesh Handshake — Identity-Safe Proximity Encryption

This document specifies how OMK Container nodes establish trust for
local mesh communication without exposing real-world identity.

## Goals

- Prove that a peer is a genuine OMK node.
- Avoid leaking user identity, phone number, or account ID.
- Support short-lived sessions with automatic key rotation.

## High-Level Flow

1. **Ephemeral Keypair**
   - Each node creates an ephemeral ECDSA/Ed25519 keypair per session:
     `K_pub`, `K_priv`.
2. **Node Pseudonym**
   - Compute `node_id = H(K_pub || salt)` where `salt` is app-provided.
   - `node_id` is stable for the session but not linkable across
     sessions without salt.
3. **Hello Frame**
   - Node broadcasts a signed hello:

```jsonc
{
  "type": "omk_hello",
  "node_id": "node-abc",
  "pubkey": "base64(K_pub)",
  "capabilities": ["context_mesh", "light_llm"],
  "ts": 1712345678000,
  "sig": "base64(Sign(K_priv, above_without_sig))"
}
```

4. **Mutual Verification**
   - Peers verify signature and freshness (ts within a short window).
   - Optional: consult Hive Bridge for attestation if cloud available.
5. **Session Key**
   - Use X25519/ECDH over K_pub values to derive a shared secret for
     encrypting L-Mesh context packets.

## Storage

- Ephemeral keys are kept in memory where possible; if stored, they
  must be in OS-provided secure storage and rotated frequently.
