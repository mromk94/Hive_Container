# Local Mesh Certificate Authority — OMK Container

Phase 5 introduces a local CA concept for authenticating OMK nodes in an
L-Mesh without exposing real-world identity.

This document defines the logical objects and flows. Crypto primitives
and platform key storage are not yet implemented (see
UNWIRED-COMPONENTS.md).

## Goals

- Bind NodeIdentity.nodeId and TwinIdentity.twinId to short-lived
  certificates.
- Allow peers to verify that a remote party is a genuine OMK node.
- Support key rotation and revocation for misbehaving nodes.

## Objects

- **MeshCertificate**
  - `cert_id`
  - `subject_node_id`
  - `issuer_id` (local CA or self-signed for first hop)
  - `valid_from` / `valid_to`
  - `capabilities` (e.g., `context_mesh`, `light_llm`)
  - `signature`

- **LocalMeshCA** (logical)
  - Issues MeshCertificates for local NodeIdentity.
  - Verifies incoming MeshCertificates from peers.

Actual signing will be delegated to platform crypto APIs in a later
phase.
