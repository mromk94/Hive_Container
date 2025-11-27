# TECH-DECISION-001 — OMK Container Stack

## Context

OMK Container extends the Hive Container vision to mobile. It needs:
- Local, privacy-first continuity and consent on phones.
- Good DX, fast iteration, and access to platform capabilities.
- A light bridge layer between mobile clients, browser extensions, and AI-Verse infrastructure.

When ambiguous, we assume **Android-first MVP**, **Flutter UI**, **Kotlin native hooks**, **Node.js Hive Bridge**, **SQLite local memory**, **TFLite** on-device, and **OpenAI/Gemini** for cloud LLMs.

## Decisions

1. **Flutter + Kotlin plugin (Android-first)**
   - Flutter for primary UI and navigation.
   - Kotlin/Android plugins for:
     - secure key storage (KeyStore),
     - TFLite runners and hardware acceleration knobs,
     - notification + background services.

2. **On-device inference with TFLite**
   - Use small distilled models (classification, intent, light summarization) on-device.
   - Heavy generative work goes to cloud LLMs via Hive Bridge.

3. **Node.js Hive Bridge backend**
   - Thin adapter between clients and LLM providers.
   - Encodes AI-Verse / Hive contracts (SessionRequest, ClientSignedToken, Vault sync).
   - Hosts safety/threat-intel checks (e.g., /analyze, /escalate, /sync-bloom in the mock).

4. **SQLite + vector store**
   - On-device SQLite for:
     - memory events,
     - persona snapshots + diffs,
     - consent + audit logs.
   - Pluggable vector store (either in-process, or backed by Rust/FFI later) for local semantic search.

## Pros / Cons

### Flutter + Kotlin
- Pros
  - Single UI codebase across Android/iOS.
  - Strong ecosystem and fast dev loop (hot reload).
  - Kotlin plugins give full access to Android platform and TFLite.
- Cons
  - Additional FFI/bridge complexity for advanced ML or crypto.
  - iOS support depends on later Swift plugin parity.

### TFLite on-device
- Pros
  - Offline continuity and safety checks.
  - Better privacy: sensitive text can be pre-filtered locally.
- Cons
  - Model size & performance constraints on low-end devices.
  - More complex model update & evaluation pipeline.

### Node.js Hive Bridge
- Pros
  - Very fast to iterate; matches existing JS/TS ecosystem.
  - Simple to deploy to serverless or containers.
  - Good fit for routing, safety filters, and logging.
- Cons
  - Not ideal for heavy numerical workloads (delegated to providers or native services).

### SQLite + vector store
- Pros
  - Mature, well-understood, embeddable DB.
  - Easy to sync / export for Hive Vault replication.
- Cons
  - Requires care for encryption-at-rest and key handling.
  - Local vector search may require additional native components.

## Migration Paths

- **UI stack**: if Flutter becomes a bottleneck, the core Vault/Bridge contracts remain TS/JSON-based, so a native Kotlin Jetpack Compose client or React Native client can reuse the same protocols.
- **Bridge backend**: Node.js can later be replaced with a typed service (e.g., Go/Rust) behind the same HTTP/JSON surface.
- **Storage**: SQLite schemas can be migrated to PostgreSQL in a remote, encrypted Vault with minimal changes to higher-level code.
- **Models**: upgrade from TFLite to on-device GGUF/LLM runtimes behind a stable "LocalModel" abstraction.
