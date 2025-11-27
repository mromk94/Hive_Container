# Content Fingerprint Schema

Small fingerprint used to identify a page/session across devices and time.

```json
{
  "url_hash": "sha256(canonical_url)",
  "title_hash": "sha256(title)",
  "screenshot_phash": "hex-encoded perceptual hash of screenshot"
}
```

- `url_hash` — sha256 of the canonicalized URL string as defined by `canonicalizeUrl()`.
- `title_hash` — sha256 of the trimmed page title.
- `screenshot_phash` — compact perceptual hash (pHash) for the screenshot image.

These fields are intentionally non-reversible but sufficient to:
- detect same/different pages over time,
- correlate local events across devices,
- avoid storing raw URLs or titles in remote storage.
