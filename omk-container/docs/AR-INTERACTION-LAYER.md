# AR Interaction Layer — OMK Container

Phase 4 introduces an augmented interaction layer on top of the Hybrid
Grid and Federated Twins.

This repo currently provides **logical models only**; ARCore/ARKit and
sensor integrations are intentionally left unwired (see
UNWIRED-COMPONENTS.md).

## Core Models

- **ARTwinEntity / ARTwinOverlayPlanner** — describe twins as luminous
  entities in AR, including brightness and health.
- **MeshHealthStatus** — aggregate mesh health metrics for ambient
  visuals.
- **GestureIntent** — high-level gesture commands (wave, point, connect)
  detected by future AR gesture recognizers.
- **ProximityStory** — brief summaries shared when twins are near in
  space.
- **AudioCuePlan** — types and intensity of audio/haptic cues for twin
  presence.
- **AiHandshakeEvent** — moments where two twins intentionally sync.
- **VoiceCommandIntent** — offline voice control intents (summon,
  dismiss, summarize, check safety).
- **EnvironmentMap / PlaneSurface** — abstract AR environment surfaces
  for anchoring twins.
- **ArVisualMode** — full vs low-power AR rendering hints.
- **RealmScene** — shared projection of twin entities that multiple
  users can see.

All AR rendering, tracking, and gesture recognition will be implemented
via platform-specific plugins in future phases.
