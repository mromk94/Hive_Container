# LLM Escalation Output Schema

The primary LLM response must conform to this JSON schema.

```json
{
  "verdict": "ALLOW|REVIEW|BLOCK|INSUFFICIENT_DATA",
  "confidence": 0.0,
  "summary_1line": "short human-readable summary",
  "evidence": ["short evidence strings"],
  "actions": ["short recommended actions"]
}
```

Constraints:

- `verdict` — one of the allowed constants.
- `confidence` — float in [0, 1].
- `summary_1line` — <= 240 characters, plain text.
- `evidence` — array of 0–5 strings, each <= 240 characters.
- `actions` — array of 0–5 strings, each <= 240 characters.

Example (BLOCK):

```json
{
  "verdict": "BLOCK",
  "confidence": 0.91,
  "summary_1line": "Login page hosted on a very new domain with suspicious certificate and text.",
  "evidence": [
    "Domain age 2 days with high-risk ASN",
    "TLS cert valid for only 30 days",
    "Page text mentions credential reset and urgent payment"
  ],
  "actions": [
    "Do not enter any passwords or payment information",
    "Close the tab and access the service via known official URL"
  ]
}
```

Example (INSUFFICIENT_DATA):

```json
{
  "verdict": "INSUFFICIENT_DATA",
  "confidence": 0.0,
  "summary_1line": "Not enough context to assess this page.",
  "evidence": ["Missing URL hash or page text"],
  "actions": ["Try again after revisiting the page or capturing more context"]
}
```
