# Hive Container — Continuity and Consent Layer

Canonical continuity layer for AI-Verse. Provides local encryption, Personality Snapshot lifecycle, and client-signed Proof-of-Consent tokens to authorize AI-Verse sessions in external worlds.

- Canonical name: Hive Container
- Upstream project: AI-Verse (https://github.com/mromk94/AIverse-Hub)
- Terminology reference: [AI-Verse Glossary](https://github.com/mromk94/AIverse-Hub/blob/main/docs/GLOSSARY.md)

## Responsibilities
- Local key management and encrypted Personality Snapshots
- Consent UX and ephemeral `ClientSignedToken`
- Snapshot versioning, export/import, selective redaction
- Bridge Registry client (list adapters/worlds)

## Architecture Overview
- Extension/App: Key custody, consent UI, snapshot manager
- Bridge Registry/API: discovery and minimal metadata exchange
- AI-Verse: consumes consented snapshots to launch sessions and spawn agents

### Data Contracts (canonical)
- ClientSignedToken
```json
{
  "sessionId": "hive_ab12cd34",
  "sub": "user_abc",
  "scopes": ["persona.use", "memory.read.limited"],
  "iat": 1712345000,
  "exp": 1712346800,
  "origin": "https://world.example",
  "signature": "base64(signature)"
}
```

## Documentation Index (this repo)
- HIVE_Container.md — Extension skeleton, messaging, security notes
- Design_Concept_for_AI_Personality.md — Personality Core proxy concept
- Adapter_Design_Bridge.md — Intent schema and adapter considerations
- Flowchart.md — Development phases and runtime flow
- VR_Design_Concept_AIverse.md — Experience/vision (AI-Verse naming retained here as context)
- VR_Implementation.md — Technical integration blueprint
- frontend.md — Frontend architecture & UI/UX spec
- The_Shared_Consciousness_Loop_SCL.md — SCL whitepaper variant

## Cross-Project Links
- AI-Verse repository: https://github.com/mromk94/AIverse-Hub
- AI-Verse Architecture: https://github.com/mromk94/AIverse-Hub/blob/main/docs/ARCHITECTURE.md
- AI-Verse SCL Whitepaper: https://github.com/mromk94/AIverse-Hub/blob/main/SHARED_CONSCIOUSNESS_LOOP_SCL.md

## Integration Summary
- Hive Container issues consent tokens and manages encrypted snapshots.
- AI-Verse validates tokens, loads snapshots (never raw memories), and orchestrates sessions.
- Adapters translate intents to world actions; Recorder logs events for audit/playback.

## Naming
- Use “AI-Verse” consistently when referring to the upstream platform.
