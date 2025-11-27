# LLM Cost Optimization & Model Tiering

## Goals

- Minimize cost and latency while maintaining safety.
- Use **small models** whenever possible.
- Reserve **large models** for rare, complex cases.

## Model Tiers (examples)

- **Tier S (small):** cheap, fast models for summaries.
  - Usage: user-friendly summaries, basic remediation text.
- **Tier M (medium):** reasoning models.
  - Usage: verdict+explain JSON, threat-intel synthesis.
- **Tier L (large):** expensive, high-capacity models.
  - Usage: only for complex investigations or SOC requests.

## Policy Rules

1. **Summary-only requests**
   - Use Tier S.
   - Max 512 prompt tokens, 256 completion.

2. **Standard escalations** (verdict+explain)
   - Default to Tier M.
   - Max 2k prompt, 512 completion.
   - Escalate to Tier L only if:
     - local + Tier M verdicts conflict across time, or
     - analyst explicitly requests deep explainability.

3. **Analyst / SOC deep dives**
   - Tier L allowed.
   - Require explicit `reason` and higher rate-limiting.

4. **Caching**
   - Cache LLM outputs keyed by:
     - `url_hash`,
     - model id,
     - prompt template id.
   - TTL: 24–72h depending on risk.
   - On cache hit, skip LLM call and return cached verdict.

5. **Token Budget Tracking**
   - For each request, track:
     - `tokens_prompt`, `tokens_completion`, `total_tokens`.
   - Maintain per-device and per-tenant daily budgets.
   - If budget exceeded:
     - Prefer cached/local decisions;
     - Mark new LLM calls as `INSUFFICIENT_DATA` and log.

6. **Graceful Degradation**
   - On provider outage or budget exhaustion:
     - Rely on on-device classifier + Bloom + security_memory.
     - Communicate clearly to users: "Cloud analysis temporarily limited".

## Implementation Hints

- Encapsulate model selection in a small router function:

```ts
function pickModel(kind: 'summary'|'verdict'|'deep', hints: {...}): ModelId { ... }
```

- Attach `modelId` and token counts to every `/escalate` response for
  observability.
