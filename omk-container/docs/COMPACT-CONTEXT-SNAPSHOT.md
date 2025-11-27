# Compact Context Snapshot (Escalation Payload)

Max size: ~2–4KB JSON, used when escalating to Hive Bridge or a safety service.

```json
{
  "url_hash": "string",
  "host": "example.com",
  "cert_summary": {
    "sha256": "string",
    "issuer": "string",
    "subject": "string",
    "valid_from": "ISO-8601",
    "valid_to": "ISO-8601"
  },
  "top_text_snippets": ["string"],
  "screenshot_hash": "string", // pHash
  "navigation_chain": [
    {
      "url_hash": "string",
      "ts": 1712345000
    }
  ],
  "local_features": {
    "risk_score": 0.0,
    "flags": ["dns_mismatch", "suspicious_cert"]
  }
}
```

- `url_hash` — canonical URL hash of the current page.
- `host` — human-readable host for debugging.
- `cert_summary` — minimal TLS cert metadata (no raw certs) from `TlsMetadataExtractor`.
- `top_text_snippets` — small set of sanitized text snippets from Accessibility/OCR.
- `screenshot_hash` — perceptual hash (pHash) of screenshot (no pixels).
- `navigation_chain` — short history of recent pages (hashed) to give context.
- `local_features` — model-friendly features (risk score, flags) computed on-device.

All text content must pass through the privacy sanitizer before being added.
