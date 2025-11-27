# Neural Switchboard v2.0 — Multi-Agent Orchestration Roadmap

## v1.0 Baseline (current)

- Context Capture Engine (CCE) for screen/app text and metadata.
- Context Normalization Layer (CNL) producing SemanticPackets.
- SecurityDecisionEngine with Bloom, on-device classifier, and Hive Bridge.
- SecurityCheckpoint (0–100 scoring, SAFE/WARN/ALERT).
- IntentRouter for security/summarization/recommendation intent planning.
- LLM Interaction Protocol with streaming, batching, offline fallback.
- MemorySync to Hive Bridge for processed security_memory entries.

## v2.0 Goals

- Move from a single decision pipeline to a **multi-agent system** where
  specialized agents collaborate:
  - SecurityAgent (threat detection, URL classification).
  - SummarizerAgent (contextual page/app summaries).
  - RecommenderAgent (next-best-actions, coaching, productivity hints).
  - PersonaAgent (user preference & long-term memory alignment).

## Architecture Sketch

1. **Agent Registry**
   - Registry describing each agent:
     - Capabilities (security|summary|recommendation|persona).
     - Cost tier (S/M/L), expected latency.
     - Input/output schemas.

2. **Agent Planner**
   - Extends IntentRouter:
     - Maps SemanticPackets + AutonomyEngine weights to agent graphs, e.g.:
       - SecurityAgent → SummarizerAgent → RecommenderAgent.
     - Uses reinforcement history to bias toward agents that yielded
       positive feedback in similar contexts.

3. **Agent Runtime**
   - Executes agent graphs with:
     - Shared context store per session.
     - Timeouts and circuit breakers.
     - Telemetry hooks for reward signals.

4. **Learning Loop**
   - Aggregate reinforcement signals:
     - Explicit thumbs up/down.
     - Implicit signals (user follows recommended action, ignores alert,
       re-runs same query, etc.).
   - Periodically update:
     - IntentRouter base priorities per intent.
     - Per-agent weights in the Agent Registry.

## Phased Plan

### Phase 1 — Feedback Plumbing

- Add UX affordances for feedback on key flows:
  - "This was helpful" / "Not helpful" buttons on security decisions.
  - Optional thumbs up/down on summaries and recommendations.
- Wire these to AutonomyEngine.recordFeedback(...) and log to Hive Bridge.

### Phase 2 — Agentized Router

- Introduce AgentPlanner that:
  - Chooses a sequence of agents instead of a single intent type.
  - Can skip agents when confidence is low or budget is exhausted.
- Start with simple chains, e.g.:
  - SecurityAgent only for high-risk contexts.
  - SummarizerAgent only for SAFE/WARN.

### Phase 3 — Cross-Session Personalization

- Use cloud memory (Hive Bridge) to:
  - Learn user-level preferences (e.g., prefers short summaries, dislikes
    aggressive prompts).
  - Store per-user agent weights and thresholds.

### Phase 4 — Multi-Agent Collaboration

- Allow agents to:
  - Propose follow-up tasks to the planner (e.g., SummarizerAgent
    suggesting a targeted SecurityAgent re-check on specific links).
  - Share compact intermediate artifacts (e.g., extracted entities,
    risk annotations) via a shared blackboard per session.

## Safety & Governance

- Keep SecurityAgent as the ultimate gatekeeper for actions that may
  expose sensitive data or execute high-risk changes.
- Preserve explicit user consent for any action that changes external
  systems (e.g., auto-report to a bank).
- Log all agent orchestration steps through audit channels similar to
  memory_sync and /escalate.
