# Federated AI Twins — OMK Container

Phase 3 defines how device-local OMK twins learn while offline and
reconcile with Hive Bridge and mesh peers on reconnect.

## Core Concepts

- **TwinIdentity** — stable identifier per user+device twin, derived
  from NodeIdentity.
- **TwinSnapshot** — compact JSON blob of routing preferences and other
  small state that can be merged.
- **TwinMeshChannel** — twin-to-twin messaging built on MeshEventBus.
 - **TwinResonanceMetric** — soft metrics for tone/knowledge/awareness
   alignment between peers.
- **PredictiveCachePlanner** — chooses which contexts to pre-cache.
- **ClusterCoordinator** — uses mesh leader selection to coordinate
  shared tasks.
- **OfflineEnvelopeStore** — store-then-forward queue for updates.

## Incremental Updates & Merge

- Devices keep local TwinSnapshot instances.
- When connectivity returns, they:
  - Send diffs (TwinStateManager.diff) to Hive Bridge or peers.
  - Merge remote snapshots via TwinStateManager.merge, preferring:
    - Newer timestamps.
    - Local-only keys when marked `local_only.*`.

## Conflict Resolution

- Latest `updated_at` wins by default for shared keys.
- Keys prefixed with `local_only.` are never overridden by remote
  snapshots.
- MeshConsensus can be used for community-level decisions (e.g.,
  malicious URL verdicts) separate from per-user twin prefs.

## Twin Signatures & Mesh

- TwinIdentity.twinId acts as the logical twin signature ID.
- NodeIdentity.nodeId remains the per-device pseudonym.
- TwinMeshChannel wraps MeshEventBus events for twin-targeted messages.

## Predictive Caching

- PredictiveCachePlanner uses recent SecurityMemoryDb entries to choose
  candidates (hosts/url_hashes) for pre-loading models or verdicts.
- In future stages, Hive Bridge can expose a predictive endpoint to send
  down likely-needed threat intel or summaries.

## Clusters & Triggers

- ClusterCoordinator and MeshLeaderSelector define which node should
  coordinate local inference batches.
- EnvironmentTriggers will route environment-derived snapshots into the
  AutonomyEngine/IntentRouter for proactive behavior when offline.
