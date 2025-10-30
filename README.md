# AI‑verse Ecosystem (by mromk94)

This repository is part of a modular, multi‑repo ecosystem implementing the AI‑verse vision and the Shared Consciousness Protocol (SCp). Together, these repos form a layered system:

- **AIverse‑Hub** — Vision & Protocol (SCp). The constitution that defines the what and why, the architecture (Axons, Nexus, Core), and the rules of the ecosystem.
- **omakh‑Hive** — Infrastructure Nexus. The decentralized task market and orchestration layer. Axons (agents) register skills and pick up tasks ("pollen"). A Queen component coordinates and delegates.
- **scout94** — Reference Axon (Agent). A practical worker agent that can browse, interact with files, and execute code; designed to plug into the Hive and execute tasks.
- **Hive_Container** — Runtime/DevOps. Ops tooling to compose and run the ecosystem across local and cloud environments. (This repo)

Links: https://github.com/mromk94/AIverse-Hub • https://github.com/mromk94/omakh-Hive • https://github.com/mromk94/scout94 • https://github.com/mromk94/Hive_Container

New entry: AI‑verse & the Shared Consciousness Protocol (SCp)
- Subject: a decentralized, multi‑agent AI ecosystem by mromk94.
- Core idea: multiple independent agents collaborate as a collective intelligence.
- Status: functional prototype spanning protocol (AI‑verse), infrastructure (omakh‑Hive), and an agent (scout94).
- Significance: a practical, layered path toward AI coordination and task delegation.

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
- SECURITY.md — Security policy and reporting guidance
- CODE_OF_CONDUCT.md — Community standards and reporting

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
