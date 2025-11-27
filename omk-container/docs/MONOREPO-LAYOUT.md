# OMK Container Monorepo Layout

Root: `omk-container/`

- `mobile/`
  - Flutter app: OMK Container mobile client.
  - Uses Riverpod, SQLite, Dio to talk to Hive Bridge.
- `native-plugins/`
  - Kotlin/Swift plugins for secure key store, TFLite, background services.
- `hive-bridge/`
  - Node.js service (mock + later real bridge) that speaks AI-Verse / Hive contracts.
- `security-db/`
  - Schemas and migration notes for local SQLite + future remote Vault.
- `docs/`
  - Technical decisions, architecture diagrams, and protocol references.

Root-level files:
- `package.json` — npm workspace definition (hive-bridge, security-db).
- `LICENSE` — Apache-2.0.
- `README.md` — mission, architecture, and quickstart.
- `.github/workflows/omk-container-ci.yml` — CI: run tests, build Android debug, sanity checks.

Workspaces:
- Node: `npm` (or `pnpm`) workspaces via `package.json`.
- Flutter: managed via `pubspec.yaml` in `mobile/`.
