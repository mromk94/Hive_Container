# Unwired Components — OMK Container / Hybrid Grid

This document tracks all major features that have scaffolding in code or
specs but are **not yet fully wired** to transports, UI, or backends.

Keeping this list current ensures no part of the Larry-State program is
forgotten.

## Phase 1 — Hybrid Core Initialization

- **ConnectivityMode auto-switching**
  - `connectivity_mode.dart` provides the enum/provider, but no service
    currently updates it based on real network status.
- **SignalTelemetry updates**
  - `signal_telemetry.dart` is now fed by NetworkTelemetry, but higher
    level planners (IntentRouter/AutonomyEngine) do not yet consume it.
- **LocalLightModel integration**
  - `HeuristicLightModel` and LarryThreatAnalyzer are used in
    SecurityDecisionEngine for offline mode, but not yet elsewhere.
- **TimeSyncedSnapshot usage**
  - `time_synced_snapshot.dart` is now consumed by MeshPacketBuilder,
    but not used by any live sync flows.
- **L-Mesh packet builders**
  - `mesh_packet_builder.dart` builds packets per
    L-MESH-CONTEXT-PROTOCOL.md, but no mesh transport currently sends
    them.
- **Crypto/runtime handshake**
  - `L-MESH-HANDSHAKE.md` specifies ephemeral keys and session setup;
    no platform crypto or key management code is wired yet.

## Phase 2 — Local Mesh Intelligence

- **MeshDiscoveryService implementations**
  - `mesh_discovery.dart` defines the interface and a Noop
    implementation; there is no Android/iOS WiFi Direct or BLE backend
    hooked up yet.
- **CoopCache persistence and sharing**
  - `coop_cache.dart` provides an in-memory cooperative cache; it is not
    yet persisted or exchanged over L-Mesh.
- **MeshEventBus transport bridge**
  - `mesh_event_bus.dart` is now bridged to OfflineEnvelopeStore via
    `mesh_transport_bridge.dart`, but no real WiFi/BLE transport or
    remote peers consume these envelopes yet.
- **AiGuardianService mesh transport**
  - `ai_guardian.dart` is now invoked from analyze_page_action, but
    emitted events are not yet forwarded over real mesh transports or
    surfaced in UI.
- **MeshConsensus in decision flows**
  - `mesh_consensus.dart` is not yet used by any concrete decision
    pipeline (e.g., URL verdicts).
- **OfflineEnvelopeStore forwarding**
  - `offline_envelope_store.dart` now has a basic worker
    (`offline_envelope_worker.dart`) that drains and logs envelopes, but
    no forwarding to Hive Bridge or mesh yet.

## Phase 3 — Federated AI Twins

- **TwinState sync to Hive Bridge**
  - `twin_state.dart` + `twin_sync_client.dart` now use /twin-sync, but
    there is no richer server-side twin store beyond echo/ack yet.
- **TwinMeshChannel transport**
  - `twin_mesh_channel.dart` emits messages onto MeshEventBus but no
    mesh transport encodes/decodes them on the wire.
- **PredictiveCachePlanner invocation**
  - `predictive_cache_planner.dart` is not yet called before
    disconnection or as part of any scheduled job.
- **ClusterCoordinator execution**
  - `cluster_coordination.dart` chooses a coordinator but no shared
    inference tasks are dispatched yet.
- **EnvironmentTriggers integration**
  - `environment_triggers.dart` accepts snapshots but nothing feeds
    real environment data into it or routes triggers into
    AutonomyEngine/IntentRouter.
- **TwinResonanceMetric usage**
  - `twin_resonance.dart` defines resonance metrics and a merge helper;
    no component currently records or consumes these metrics.

## Phase 4 — AR Interaction Layer

- **ARCore/ARKit bindings**
  - No native AR session, camera, or tracking code is wired; all AR
    types are logical models only.
- **AR twin overlay rendering**
  - `ar_twin_overlay.dart`, `realm_projection.dart`, and
    `environment_mapping.dart` are not yet connected to Flutter
    widgets or platform views.
- **Mesh health visualization**
  - `mesh_health_visuals.dart` defines a model but no UI currently uses
    it to drive ambient light/icon intensity.
- **Gesture detection**
  - `gesture_channel.dart` defines gesture intents; no gesture
    recognizers or AR frameworks feed into it.
- **Proximity stories transport**
  - `proximity_story.dart` is not wired to TwinMeshChannel or mesh
    transports yet.
- **Audio/haptic cues**
  - `audio_cues.dart` provides cue descriptions but no OS-level audio
    or haptics integration exists.
- **AI handshake flows**
  - `ai_handshake.dart` is not invoked by any UX or mesh logic yet.
- **Voice command recognition**
  - `voice_commands.dart` defines offline intents; no speech
    recognition or keyword spotting is integrated.
- **Shared Realm synchronization**
  - `realm_projection.dart` describes a shared scene, but no multi-user
    sync or conflict resolution is implemented for Realm projections.

## Phase 5 — Security + Memory Integrity

- **LocalMeshCA crypto**
  - `LOCAL-MESH-CA.md` and `mesh_certificate_authority.dart` define
    logical shapes, but no real signing/verification or key storage is
    implemented.
- **LarryThreatAnalyzer integration**
  - `larry_threat_analyzer.dart` is now used by SecurityDecisionEngine
    when ConnectivityMode is offline, but not yet integrated into
    backend LLM fallbacks.
- **MeshLedger persistence and usage**
  - `mesh_ledger.dart` computes chained hashes for entries, but no
    component writes to or validates this ledger yet.
- **NodeQuarantineManager enforcement**
  - `node_quarantine.dart` now has policy helpers in
    `mesh_routing_policy.dart`, but mesh discovery and routing do not
    yet call them.
- **SecurityTicket routing**
  - `security_ticket.dart` enqueues tickets into OfflineEnvelopeStore;
    no worker forwards them to Hive Bridge or admins yet.
- **MeshPersistenceHelper durability**
  - `mesh_persistence.dart` defines snapshot helpers, but no underlying
    durable storage implementation exists.

## Phase 6 — Community Intelligence

- **MicroCommunityBoard UI and sync**
  - `community_board.dart` is not surfaced in any UI or shared over
    mesh/cloud yet.
- **KnowledgePool sharing**
  - `knowledge_pool.dart` stores items locally; no pooling or
    reconciliation happens across peers.
- **EventTag producers/consumers**
  - `event_tagging.dart` defines tags but no code creates or reads them
    in response to environment changes.
- **LearningPulse orchestration**
  - `learning_pulse.dart` models cycles; no scheduler coordinates pulses
    or aggregates results.
- **AiScoutMission execution**
  - `ai_scouts.dart` describes missions; no path dispatches or reports
    on them.
- **Community milestones computation**
  - `community_milestones.dart` defines metrics; nothing updates or
    displays them.
- **Group problem-solving runtime**
  - `group_problem_solving.dart` describes sessions but no runtime ties
    them to chat/LLM/mesh flows.
- **ResourceSnapshot collection**
  - `resource_tracker.dart` is not fed by real battery/compute stats or
    used for load balancing.
- **RegionalGatewayState wiring**
  - `regional_gateway.dart` is not connected to any actual gateways or
    sync logic.
- **AiVillageCluster visualization**
  - `ai_villages.dart` defines clusters; no map/graph UI renders them or
  keeps them updated.

## Phase 7 — Optimization & Evolution

- **PacketScheduler integration (mesh)**
  - `packet_scheduling.dart` is used by MemorySyncClient, but not yet by
    any mesh transport or AR/event channels.
- **Emergency SMS signaling**
  - `emergency_sms.dart` models signals but no SMS send/receive is
    implemented.
- **SyncPolicyConfig usage**
  - `sync_policy.dart` is not referenced by MemorySyncClient or other
    workers.
- **StartupCachePlan execution**
  - `startup_cache_plan.dart` is not tied into app startup sequences.
- **DialogueSmoothingProfile usage**
  - `dialogue_smoothing.dart` is not applied to any UI streaming logic.
- **RoutingHint computation**
  - `predictive_routing.dart` defines hints but no planner calculates
    them.
- **ShadowModelManifest management**
  - `shadow_llm_manager.dart` describes minimal models but no download
    or load path exists.
- **TopologyStats collection**
  - `topology_evolution.dart` is not populated from mesh telemetry.
- **MirrorNodeDescriptor deployment**
  - `mirror_nodes.dart` is not wired to any discovery or sync.
- **UIP enforcement**
  - `UNIFIED-INTELLIGENCE-PROTOCOL.md` describes intent; no runtime
    checks enforce UIP invariants yet.

## General / Cross-Cutting

- **Native mesh transports**
  - No actual WiFi Direct, BLE, or hotspot-based networking code is
    implemented yet for OMK Container; all mesh-related interfaces are
    currently logical scaffolding.
- **Backend support for twins/mesh**
  - Hive Bridge now has basic /twin-sync and a verdict_cache schema,
    but there is still no full mesh telemetry or coop cache ingestion
    pipeline.
- **UI surfaces**
  - MeshStatusScreen now surfaces basic mesh alerts and connectivity,
    but there is still no dedicated UI for community boards or deep
    mesh diagnostics.
