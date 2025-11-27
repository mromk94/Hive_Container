# URL Risk Model Versioning & Update Plan

## Overview

The URL risk classifier runs fully on-device as a small TFLite model.
Updates are shipped as binary blobs with metadata via Hive Bridge, then
validated and installed locally.

## Metadata

Each model is described by a small JSON document:

```json
{
  "model_id": "url_risk_v1",
  "version": "2025-11-01",
  "size_bytes": 123456,
  "sha256": "...",
  "min_app_version": "0.1.0",
  "created_at": "2025-11-01T12:00:00Z"
}
```

## Update Flow

1. Mobile app queries Hive Bridge for latest metadata (e.g. `/model/url-risk`).
2. If `version` differs from local `url_risk_model_version` and app version is
   compatible, app downloads the TFLite bytes.
3. App calls `UrlRiskModelStore.installModel(bytes, version, sha256)` which:
   - verifies checksum,
   - writes to a versioned file under app documents dir,
   - validates it can be opened by TFLite,
   - records previous version/path for rollback.
4. On next decision cycle, `UrlRiskModel.load(filePath: currentPath)` is used.

## Frequency

- Default: **weekly** checks.
- Optionally: **daily** during early rollout or when high-risk campaigns are
  detected.

## Rollback Strategy

- If a newly installed model fails validation or causes obvious issues
  (e.g. always-block behavior), the app can call
  `UrlRiskModelStore.rollback()` to restore the previous path + version.
- Hive Bridge can also signal a bad release in metadata, prompting clients to
  roll back automatically.

## On-Device Validation

Before switching models, clients should:

- Run the model on a small built-in validation set of synthetic feature
  vectors and ensure outputs stay within expected ranges.
- Optionally compare distribution of scores against previous model.

These checks can be implemented in a background task and should not block UI.
