# LLM Interaction Protocol

Defines how Hive Bridge talks to LLM providers (or local stubs).

## Capabilities

- **Streaming responses** — via async generators on the server and
  SSE/WebSocket framing to clients.
- **Priority task batching** — tasks enqueued with priorities and
  processed in order.
- **Context-aware prompts** — inject app name, action type, and compact
  context snapshot into prompts.
- **Local fallback** — offline mode driven by `LLM_OFFLINE=1` env var,
  using deterministic fallback outputs.

## Interaction Request JSON Schema

A full interaction request (server-internal, or exposed via an admin API)
looks like this:

```json
{
  "id": "task-123",
  "kind": "security",        // security | summary | threat_intel | remediation
  "priority": 0.9,
  "stream": true,
  "context": {
    "appLabel": "MyBank",
    "appPackage": "com.bank.app",
    "actionType": "analyze_page",
    "snapshot": {
      "url_hash": "sha256(canonical_url)",
      "host": "login.mybank.com",
      "cert_summary": {
        "sha256": "...",
        "issuer": "...",
        "subject": "...",
        "valid_from": "2025-10-01T00:00:00Z",
        "valid_to": "2025-12-30T00:00:00Z"
      },
      "top_text_snippets": [
        "Sign in to your account",
        "Confirm your identity"
      ],
      "screenshot_hash": "phash-hex",
      "navigation_chain": [
        { "url_hash": "...", "ts": 1712345000 }
      ],
      "local_features": {
        "domain_age_days": 3.5,
        "asn_reputation_score": 0.8
      }
    },
    "localSignals": {
      "bloom_hit": true,
      "local_risk_score": 0.76,
      "checkpoint_score": 88,
      "checkpoint_level": "ALERT"
    }
  }
}
```

## Response Shapes

### Non-streaming

```json
{
  "model": "tier-M-security-model",
  "prompt": { "system": "...", "user": {"snapshot": {"..."}, "local_signals": {"..."}} },
  "output": {
    "verdict": "BLOCK",
    "confidence": 0.9,
    "summary_1line": "High-risk phishing login page on new domain.",
    "evidence": ["..."],
    "actions": ["..."]
  },
  "validation": {
    "ok": true,
    "errors": []
  }
}
```

### Streaming

Server-side, `runTaskStream(task)` is an async generator that yields text
chunks. Over the wire, these can be framed as SSE events like:

```text
event: chunk
data: {"taskId":"task-123","chunk":"High-risk phishing "}

event: chunk
data: {"taskId":"task-123","chunk":"login page on new domain."}

event: done
data: {"taskId":"task-123"}
```

## Offline Fallback

When `LLM_OFFLINE=1`, the interaction layer:

- Skips provider calls.
- Returns a deterministic output:
  - `verdict: "INSUFFICIENT_DATA"`
  - `summary_1line: "Offline mode: using local protections only."`
  - Evidence/actions explaining that fallback was used.

Clients must treat this as a hint to rely solely on on-device
classifiers and cached decisions.
