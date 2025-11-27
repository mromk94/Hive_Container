# Larry-State Unified Intelligence Protocol (UIP)

The UIP defines how OMK Container merges cloud, local, and mesh
reasoning into a coherent Larry-State continuum.

## Layers

- **Local** — Context Capture Engine, CNL, SecurityDecisionEngine,
  LocalLightModel, on-device caches.
- **Mesh** — L-Mesh topology, coop cache, federated twins, community
  intelligence.
- **Cloud** — Hive Bridge, LLM interaction layer, Queen Cloud APIs.

## Principles

- Prefer local and cached decisions when safe.
- Use mesh to enrich and protect when cloud is unavailable.
- Escalate to cloud when high-risk, complex, or explicitly requested.

## Routing

- ConnectivityMode and RoutingHint guide which layer to use.
- AutonomyEngine and IntentRouter assemble plans that can span layers,
  e.g. local risk check → mesh cache → cloud escalation.

## State

- TwinSnapshot and MeshPersistenceSnapshot capture durable state for
  continuity.
- UNWIRED-COMPONENTS.md tracks remaining integration work.
