# Hive Container Chrome Extension — Blueprint

This blueprint captures the vision, scope, architecture, security model, and a living, modular TODO for the Hive Container Chrome extension. It aligns with AIverse‑Hub, omakh‑Hive, and scout94.

---

## 1. Vision & Scope
- Carry the user’s AI Persona (Personality Snapshot) across the web via a privacy‑first browser extension.
- Provide explicit consent UX and short‑lived client‑signed tokens that third‑party sites can verify.
- Forward allowed, scoped requests to LLM providers using locally stored encrypted creds.
- Never expose raw private memories to third‑party sites; only intended action outputs.

Out of scope (MVP): bridge backend, multi‑engine voice/rtc; advanced adapters; complex registries.

---

## 2. Roles in the Ecosystem
- AIverse‑Hub: protocol + SCL; defines Core contracts and flows.
- omakh‑Hive: infra nexus; registry/API exemplars; security rigor.
- scout94: QA/clinic; can exercise handshake flows and validate safety.
- Hive Container (this): continuity + consent; client crypto; proof‑of‑consent tokens; secure forwarding.

---

## 3. Contracts (Frozen, from HIVE_Container.md)
- SessionRequest (page → extension)
- ClientSignedToken (extension → page)
- Message Types: HIVE_CONNECT_REQUEST, HIVE_SESSION_REQUEST, SHOW_SESSION_REQUEST, HIVE_CREATE_TOKEN, HIVE_SESSION_APPROVED, HIVE_FORWARD_REQUEST, APP_FORWARD_REQUEST, HIVE_FORWARD_RESPONSE

References: HIVE_Container.md “Canonical Contracts”.

---

## 4. Permissions & Manifest (MV3)
Required (MVP):
- permissions: storage, activeTab, scripting, tabs, notifications
- host_permissions: <all_urls> (will narrow post‑MVP)
- background: service_worker = dist/background.js
- action: default_popup = dist/popup.html
- content_scripts: dist/contentScript.js (document_start)
- web_accessible_resources: dist/popup.html, icons/*

Hardening (post‑MVP): narrow matches; origin allowlist; optional declarativeNetRequest.

---

## 5. Messaging Topology
- page ↔ content: window.postMessage events
- content ↔ background: chrome.runtime messages
- background ↔ popup: chrome.runtime messages + chrome.action.openPopup
- background ↔ active tab: chrome.tabs.sendMessage

---

## 6. UI/UX (Popup)
States: idle, request_received, details_view, approved, denied, revoked, expired, error.
Key views:
- Consent card (origin, scopes, persona, TTL)
- Minimal settings (dev only): set sample user
- Token issuance confirmation

---

## 7. Storage & Crypto
- Keys: OS keystore preferred; fallback WebCrypto (AES‑GCM) with passphrase.
- Provider tokens: encrypted‑at‑rest; decrypted only in memory.
- Token signing: WebCrypto (ECDSA P‑256 or Ed25519) signing of canonical payload `sub|sessionId|scopes|iat|exp|origin`.

---

## 8. Forwarding Engine (Providers)
- MVP: OpenAI Chat Completions as exemplar.
- v0.2: Provider registry (OpenAI, Gemini, Claude, local/server LLM), per‑provider rate‑limits.

---

## 9. Validation & Security
- Origin match required (token.origin == page origin).
- TTL ≤ 30 min; rotation supported.
- Revocation list by sessionId.
- Scopes gate forwarded operations; policy default deny.
- Threats: spoofed origin, replay, key exfiltration, scope escalation → mitigations as per HIVE_Container.md.

---

## 10. Telemetry & Audit (Client‑side)
- Ephemeral audit log: hashes of responses, timestamps.
- No raw content persisted.
- Optional: export anonymized metrics for diagnostics.

---

## 11. Build & Tooling
- Language: TypeScript
- Bundler: esbuild (simple) or webpack
- Outputs: dist/background.js, dist/contentScript.js, dist/popup.js, dist/popup.html
- Icons: icons/{16,48,128}.png (placeholders okay in MVP)

---

## 12. Dev Sandbox & Demo
- Demo snippet for page handshake (provided in HIVE_Container.md)
- Optional HCP Gateway mock (Node+Express) to issue session URIs and validate ClientSignedToken

---

## 13. Milestones & Modular TODOs

### 13.1 MVP (v0.1)
Deliverables:
- Manifest v3 with required permissions
- contentScript, background, popup (TS → dist/*)
- Consent flow: receive SessionRequest, show origin+scopes, approve/deny
- Token creation stub (replace hashing with temporary dev signature)
- Forwarding: OpenAI POST using encrypted dev token placeholder
- Validation: origin check, TTL, sub match; basic error codes
- Audit: store hashed response metadata

Tasks (files/components):
- manifest.json
- src/types.ts: SessionRequest, ClientSignedToken
- src/background.ts: onMessage routes, createClientSignedToken, handleAppForwardRequest, audit hashing
- src/contentScript.ts: postMessage listeners for CONNECT/FORWARD
- src/popup.html + src/popup.ts: consent UI, HIVE_CREATE_TOKEN call, approval path
- build scripts (package.json), esbuild config or commands
- icons placeholders

Acceptance:
- Demo page can request connect → popup shows request → approve → page receives token → forward request → provider returns JSON → demo displays result.

### 13.2 v0.2 Security & Crypto
- Replace stub signature with WebCrypto signing (ECDSA P‑256 or Ed25519)
- Key storage: OS keystore where possible; fallback AES‑GCM with passphrase
- Token revocation + single‑use option for sensitive scopes
- Rate limits per scope; exponential backoff
- Narrow host_permissions; begin origin allowlist

### 13.3 v0.3 Provider & Policy Expansion
- Provider registry UI in popup (OpenAI, Gemini, Claude, local)
- Per‑provider creds management (encrypted)
- Scopes matrix UI and enforcement
- HCP Gateway mock server (node) for session issuance + token verification
- Export minimal logs for scout94 audits

### 13.4 v1.0 Polishing & Release
- Full error surfaces, i18n, accessibility
- End‑to‑end tests (Playwright), unit tests (Jest)
- CI (GitHub Actions) build & package
- Chrome Web Store preparation (assets, listing)

---

## 14. Work Plan (Living Checklist)

- [ ] MVP manifest.json defined and validated
- [ ] src/types.ts with exact contracts
- [ ] background: session request handling, consent routing, forwarder stub
- [ ] contentScript: page bridge handlers
- [ ] popup: consent UI, token issuance call, success path
- [ ] esbuild scripts and npm tasks
- [ ] icons placeholders
- [ ] demo page snippet wired and tested locally
- [ ] README (extension) with install/build steps

Post‑MVP
- [ ] WebCrypto signing + key storage
- [ ] Revocation + single‑use
- [ ] Provider registry + encrypted creds manager
- [ ] Origin allowlist + permission narrowing
- [ ] HCP Gateway mock + verification

---

## 15. Links
- HIVE_Container.md (contracts, flows, code skeleton)
- AIverse‑Hub/docs/ARCHITECTURE.md (system map, APIs)
- AIverse‑Hub/SHARED_CONSCIOUSNESS_LOOP_SCL.md (SCL)
- omakh‑Hive/docs/ (backend/API cues)
- scout94 docs (communication, audits)
