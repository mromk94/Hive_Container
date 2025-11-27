# Hive Bridge Escalation API

The `/escalate` endpoint coordinates LLM-backed analysis and ticketing
for high-risk events.

## Endpoint

- **Method:** `POST`
- **Path:** `/escalate`
- **Body:**

```json
{
  "incidentId": "optional client-generated id",
  "context": {
    "snapshot": { /* Compact context snapshot JSON */ },
    "local_decision": {
      "verdict": "allow|review|block",
      "risk_score": 0.0,
      "path": ["bloom_miss", "cache_miss", "model_classifier:0.72"]
    },
    "user_note": "optional free-text note from user"
  }
}
```

- **Response:**

```json
{
  "ok": true,
  "ticketId": "OMK-ABC12345",
  "verdict": "ALLOW|REVIEW|BLOCK|INSUFFICIENT_DATA",
  "llm": {
    "model": "gpt-4.1-mini",
    "tokens_prompt": 512,
    "tokens_completion": 128
  },
  "llm_output": {
    "verdict": "BLOCK",
    "confidence": 0.86,
    "summary_1line": "...",
    "evidence": ["..."],
    "actions": ["..."]
  },
  "rate_limited": false,
  "retry_after_seconds": 0
}
```

If rate limited or degraded, the server may skip LLM calls and return
`llm_output` with `verdict="INSUFFICIENT_DATA"` and `rate_limited=true`.

## Rate Limiting Policy

- Per-device soft limit: e.g. **20 escalations / day**.
- Per-IP hard limit: e.g. **200 escalations / day**.
- Burst control: **5 escalations / 5 minutes** per device.

On limit hit:

- Return HTTP `429` with JSON:

```json
{
  "ok": false,
  "error": "rate_limited",
  "retry_after_seconds": 600
}
```

Clients should:

- Fall back to local classifier + cached verdict.
- Surface a message like: "Escalation busy, using local protections only".

## Token Budget & Fallbacks

- Each escalation has a **total token budget**, e.g. **3k tokens**.
- The server should:
  - Truncate context snapshot (top text snippets, compact evidence) to
    stay within budget.
  - Prefer smaller models where possible (see LLM-COST-POLICY.md).

Failure modes:

1. **LLM call fails or times out**
   - Mark `llm_output.verdict="INSUFFICIENT_DATA"`.
   - Preserve local decision in `context.local_decision`.
2. **Schema validation fails**
   - Treat response as `INSUFFICIENT_DATA`.
   - Log the raw output for debugging on the server side only.

## Notes

- `/analyze` remains a lightweight risk scoring endpoint; `/escalate` is
  reserved for heavier, human- or SOC-facing flows.
- All PII should be sanitized in the client before sending context.
