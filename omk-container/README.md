# OMK Container
 
Android-first mobile Hive Container and Hive Bridge monorepo.

This folder is the **mobile/runtime counterpart** to the existing Hive Container browser extension. It provides:
- A Flutter-based mobile client (Android-first) for continuity and consent.
- A Node.js Hive Bridge backend for LLM routing and safety analysis.
- Shared contracts for Persona / Vault / Session flows across devices.

---
 
## Mission
 
Carry the user’s AI Persona beyond the browser into native mobile surfaces while preserving:
- **Privacy-first continuity** (local, encrypted memory and persona snapshots).
- **Explicit consent** for any external AI or adapter that touches the persona.
- **Shared Consciousness Loop** semantics across desktop, mobile, and future worlds.

OMK Container extends the existing Hive Container so a single persona + Vault can hydrate:
- Browser AIs (via the extension).
- Mobile-native flows (journaling, notifications, local agents).
- Downstream adapters via the Hive Bridge.

---
 
## Architecture Overview
 
High-level layout (see `docs/MONOREPO-LAYOUT.md` for details):
 
```text
omk-container/
  mobile/          Flutter app (Android-first)
  native-plugins/  Kotlin / Swift plugins (keys, TFLite, OS hooks)
  hive-bridge/     Node.js Hive Bridge + mock safety endpoints
  security-db/     SQLite schemas + future Vault migration notes
  docs/            Tech decisions and architecture refs
  scripts/         Dev bootstrap helpers
  .github/workflows/omk-container-ci.yml
```
 
Data & control flow (simplified):
 
```text
Flutter UI  <-->  Native plugins (Kotlin/Swift, TFLite, key store)
      |                      |
      v                      v
 SQLite + local Vault  <--> Hive Bridge (Node.js)  <--> Cloud LLMs (OpenAI, Gemini, ...)
```
 
---
 
## Quickstart (Dev)
 
### 1) Clone & install
 
```bash
git clone https://github.com/mromk94/Hive_Container.git
cd Hive_Container/omk-container
 
# Node workspaces (Hive Bridge, security-db)
npm install
 
# Flutter deps
cd mobile
flutter pub get
```
 
### 2) Run tests
 
```bash
# Hive Bridge tests
cd ../
npm run test:hive-bridge
 
# Flutter unit tests
cd mobile
flutter test
```
 
### 3) Run Hive Bridge mock server
 
```bash
cd ../
npm --workspace hive-bridge run dev
 
# Example call
curl -X POST http://localhost:4317/analyze \
  -H 'Content-Type: application/json' \
  -d '{"text":"test prompt with api_key"}'
```
 
### 4) Build Android debug APK
 
```bash
cd mobile
flutter build apk --debug
```
 
CI runs equivalent steps via `.github/workflows/omk-container-ci.yml`.
 
---
 
## Contributing
 
- Read `CODE_OF_CONDUCT.md` for interaction guidelines.
- Contributions are accepted under the terms of `CLA.md` and the Apache-2.0 license.
- For larger changes, open an issue or a design note in `docs/` before submitting a PR.
 
---
 
## License
 
OMK Container is licensed under the **Apache License 2.0**. See `LICENSE` for details.
 
---
 
## Contact
 
For questions, ideas, or security reports related to OMK Container mobile / Hive Bridge:
 
- GitHub Issues: use the issue tracker on the main repository.
- Direct contact: see the maintainer contact section in the root `README.md` of this repo.
