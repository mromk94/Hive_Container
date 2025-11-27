# URL Risk On-Device Classifier — Feature Spec

## Feature Vector

Each sample is a single page/session. Features are numeric and normalized in
training.

1. `domain_age_days` (float)
   - Days between domain registration and observation time.
   - Source: WHOIS / CT logs.
   - Rationale: very young domains are more likely malicious.

2. `cert_valid_days` (float)
   - `cert_not_after - cert_not_before` in days.
   - Source: TLS cert metadata from `TlsMetadataExtractor`.
   - Rationale: short-lived certs can correlate with abuse.

3. `redirect_count` (int)
   - Number of HTTP(S) redirects followed before landing on this URL.
   - Source: browser/network logs.
   - Rationale: long redirect chains common in tracking / phishing funnels.

4. `path_entropy` (float)
   - Shannon entropy (bits/char) of URL path string.
   - Rationale: random-looking paths often indicate tracking or generated links.

5. `host_entropy` (float)
   - Shannon entropy of the host (FQDN) string.
   - Rationale: algorithmic subdomains / combosquatting tend to have higher
     entropy.

6. `domain_edit_distance` (float)
   - Normalized Levenshtein distance between effective second-level domain
     (e.g. `paypa1.com`) and closest known brand/domain in a curated list.
   - Values in [0, 1], where 0 = same string, 1 = maximally different.
   - Rationale: detects lookalike domains (paypal vs paypa1).

7. `asn_reputation_score` (float)
   - Score in [0, 1] representing ASN risk, where 0 is benign, 1 is highly
     abusive.
   - Source: offline feed combining Spamhaus / abuse DBs.

8. `page_text_entropy` (float)
   - Entropy of visible page text (after language detection and normalization).
   - Rationale: very low entropy (template-like) or unusually high entropy
     (gibberish, random strings) can be suspicious.

All features should be z-scored or otherwise normalized during training; the
TFLite model expects a fixed ordering:

```text
[domain_age_days,
 cert_valid_days,
 redirect_count,
 path_entropy,
 host_entropy,
 domain_edit_distance,
 asn_reputation_score,
 page_text_entropy]
```

## Label Space

Binary or ternary label, depending on dataset:

- `0` — benign / safe
- `1` — phishing / malicious
- Optional: `2` — gray / unknown (can be treated as 0.5 during training).

## Dataset Schema

Tabular dataset in CSV/Parquet form with the following columns:

- `url` (string) — full URL.
- `host` (string) — extracted host.
- `label` (int) — 0/1(/2) ground-truth.
- `domain_created_at` (timestamp) — WHOIS/registry creation time.
- `observed_at` (timestamp) — time of crawl/observation.
- `cert_not_before` (timestamp, nullable).
- `cert_not_after` (timestamp, nullable).
- `redirect_count` (int).
- `asn` (int) — origin autonomous system number.
- `asn_reputation_score` (float in [0, 1]).
- `page_text` (string) — normalized visible text.

Engineered columns (can be computed in pipeline or pre-computed):

- `domain_age_days` (float).
- `cert_valid_days` (float).
- `path_entropy` (float).
- `host_entropy` (float).
- `domain_edit_distance` (float).
- `page_text_entropy` (float).

Minimal JSON example for one row after feature engineering:

```json
{
  "url": "https://paypa1-login.com/security-check",
  "host": "paypa1-login.com",
  "label": 1,
  "domain_age_days": 3.5,
  "cert_valid_days": 90.0,
  "redirect_count": 2,
  "path_entropy": 3.4,
  "host_entropy": 3.1,
  "domain_edit_distance": 0.2,
  "asn_reputation_score": 0.8,
  "page_text_entropy": 2.9
}
```

The on-device model will only see the 8 numeric features; raw URLs/text are
kept off-device or stored locally only under strict privacy rules.
