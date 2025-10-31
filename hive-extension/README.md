# Hive Container Chrome Extension (MV3)

Carry your AI persona across the web with explicit consent, client-side cryptography, and scoped forwarding.

## Features
- Consent UX for site session requests (origin, scopes, persona)
- Client-signed, short-lived tokens (ES256 via WebCrypto)
- Origin-bound tokens with TTL and optional single-use
- Scoped forwarding to providers (OpenAI example) with encrypted token storage (MVP in local storage)
- Revocation and single-use enforcement
- Content bridge (page <-> extension) and demo page for E2E testing

## Project Structure
- manifest.json
- src/
  - background.ts — message routing, token creation, forwarder, enforcement
  - contentScript.ts — page bridge using window.postMessage
  - popup.html/.ts — consent UI and approve/deny
  - types.ts — canonical contracts
  - crypto.ts — ES256 WebCrypto key mgmt + signing
  - config.ts — origin allowlist (dev)
- dist/ — build outputs
- demo/index.html — local demo of handshake + forward

## Setup
- Requirements: Node 18+
- Install deps:
  - `npm install`
- Build:
  - `npm run build`

## Load in Chrome
1. Open `chrome://extensions`
2. Enable Developer Mode
3. Click “Load unpacked”
4. Select the folder `hive-extension` (it must contain `manifest.json`)
5. Optional: Toggle “Allow access to file URLs” if using the file-based demo

## Demo
- Open `demo/index.html` in Chrome (or serve via localhost)
- Click “Connect Hive” → approve in popup
- Click “Forward Example Request”
- With a placeholder/invalid provider token, expect an error JSON (verifies forwarding path)
- Without provider token, the extension responds with an echo fallback

## Messaging Contracts
- Page → Content: `window.postMessage`
- Content ↔ Background: `chrome.runtime.sendMessage`
- Background ↔ Popup: `chrome.runtime.sendMessage` and `chrome.action.openPopup`
- Key message types: `HIVE_SESSION_REQUEST`, `SHOW_SESSION_REQUEST`, `HIVE_CREATE_TOKEN`, `APP_FORWARD_REQUEST`, `HIVE_SESSION_APPROVED`, `HIVE_FORWARD_RESPONSE`

## Security
- ES256 signing of canonical payload: `sub|sessionId|scopes|iat|exp|origin`
- Origin match and TTL enforced on forward
- Optional `singleUse` tokens (auto-marked used after first forward)
- Session revocation supported (in-memory via Chrome storage for MVP)
- Origin allowlist (configurable in `src/config.ts`)

## Permissions
- Minimum:
  - `storage`, `activeTab`, `scripting`, `tabs`, `notifications`
- Host permissions: narrowed for dev (e.g., localhost). For production, prefer an explicit allowlist and fine-grained matches.

## Roadmap
- Secure key storage (OS keystore) and passphrase-based fallback
- Provider registry UI (OpenAI, Gemini, Claude, local) + encrypted creds manager
- Narrow permissions to specific origins; declarativeNetRequest where applicable
- HCP Gateway mock server for token verification
- Tests (Jest/Playwright), CI, packaging, and store listing assets

## Core Vision (Portable Persona + Handshake + Shared Consciousness)
- Your personal AI persona travels with you across the web.
- When a site has its own AI, Hive performs a consented handshake so the site AI temporarily adopts your persona.
- A rolling context (shared memory loop) maintains continuity and preferences.
- Privacy controls (allowlist/denylist) keep you in control per origin.

### Implementation Path (V1)
1. Persona Profile schema + encrypted storage + popup editor (sliders and notes).
2. Handshake Protocol v1: GET_PERSONA, SUGGEST_REPLY, UPDATE_CONTEXT with approvals.
3. Generic Chat Adapter v1: floating “Ask My Hive” near textareas, suggestion panel.
4. Shared memory per session/origin; inject into provider prompts.
5. Privacy controls (allow/deny per origin + quick toggle UI/banner).

## Troubleshooting
- "Could not load manifest" — ensure you selected the `hive-extension` folder
- "Content script not running on demo" — enable “Allow access to file URLs” or serve via localhost
- 401/403 from provider — replace placeholder token with a valid provider API key
