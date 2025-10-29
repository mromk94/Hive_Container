It’s privacy-first: the extension holds the user’s provider tokens locally (encrypted placeholder), shows a clear permission card, and creates a client-signed ephemeral session token that the web app can use to request LLM calls via the extension (direct client-only transport). This skeleton focuses on the handshake and forwarding plumbing — the trust anchor for the whole transporter model.

Below are the files and instructions. Copy each file into your extension project, tweak the HCP_GATEWAY_URL and crypto/signing parts to match your key management, and load the extension in Chrome (developer mode).


Terminology reference: [AI-Verse Glossary](https://github.com/mromk94/AIverse-Hub/blob/main/docs/GLOSSARY.md)

---

## Canonical Contracts (Frozen)

These are the canonical, implementation-agnostic contracts used across AI-Verse and Hive Container. Code samples below may show placeholders; when in doubt, these contracts take precedence.

### SessionRequest (page → extension)
```json
{
  "sessionId": "hive_ab12cd34",
  "appOrigin": "https://world.example",
  "requestedScopes": ["persona.use", "memory.read.limited"],
  "requestedPersona": "default",
  "nonce": "random_base64",
  "createdAt": 1712345000
}
```

### ClientSignedToken (extension → page)
```json
{
  "sessionId": "hive_ab12cd34",
  "sub": "user_abc",
  "scopes": ["persona.use", "memory.read.limited"],
  "iat": 1712345000,
  "exp": 1712346800,
  "origin": "https://world.example",
  "signature": "base64(signature)"
}
```

### Message Contracts

- window.postMessage (page → content script)
  - `HIVE_CONNECT_REQUEST`: `{ payload: SessionRequest }`
  - `HIVE_FORWARD_REQUEST`: `{ payload: { sessionToken: ClientSignedToken, requestPayload: any } }`

- content script → background
  - `HIVE_SESSION_REQUEST`: `{ payload: SessionRequest }`
  - `APP_FORWARD_REQUEST`: `{ payload: { sessionToken: ClientSignedToken, requestPayload: any } }`

- background → popup
  - `SHOW_SESSION_REQUEST`: `{ payload: SessionRequest }`

- popup → background (optional helper)
  - `HIVE_CREATE_TOKEN`: `{ payload: { userId: string, sessionId: string, scopes: string[], origin: string } }`
    - response: `{ token: ClientSignedToken }`

- background → content (to active tab)
  - `HIVE_SESSION_APPROVED`: `{ payload: { token: ClientSignedToken } }`

Security notes
- `origin` MUST be included in `ClientSignedToken` and validated before forwarding any requests.
- Tokens MUST be short-lived and verified against current user and scopes.

---

## Storage & Encryption Interfaces (Frozen)

Implementation-agnostic contracts for client-side key custody and encrypted Personality Snapshots.

### Keyring Interface
- `generateKeypair(alg = "ECDSA_P-256" | "Ed25519") -> KeyPair`
- `storePrivateKey(keyId, key, protection = "os_keystore" | "passphrase_webcrypto") -> KeyRef`
- `getPublicKey(keyId) -> PublicKeyJwk`
- `sign(keyId, bytes) -> signature(Base64)`
- `rotateKey(keyId) -> NewKeyRef`
- `lock()/unlock(passphrase?)`

Notes
- Prefer OS keystore where available; otherwise encrypt private keys with WebCrypto AES-GCM using a passphrase-derived key (PBKDF2/Argon2).

### Snapshot Interface
- Schema (metadata only; payloads are encrypted blobs)
```json
{
  "id": "ps_123",
  "version": 3,
  "owner_id": "user_abc",
  "artifacts": {
    "embeddings": "enc:blob://snapshots/ps_123/embeddings",
    "fine_tune": "enc:blob://snapshots/ps_123/ft"
  },
  "policies": {"autonomy": "low", "spending_caps": {"daily": 50}},
  "created_at": 1712345000,
  "updated_at": 1715345000
}
```

- Operations
  - `createSnapshot(inputs) -> {id}`
  - `versionSnapshot(id, changes) -> {version}`
  - `exportEncryptedSnapshot(id, recipientPubKey) -> Blob`
  - `importEncryptedSnapshot(blob) -> {id}`
  - `redactSnapshot(id, paths[]) -> {diff_id}` (irreversible delete of selected content with audit metadata preserved)

### Crypto Primitives
- Content encryption: AES-GCM (128/256) with random 96-bit IVs.
- Envelope encryption: ECDH/XSalsa-KEM to encrypt content keys to recipient public keys (or locally to self).
- Hashing for audit: SHA-256.

### Storage Layout (Client)
- Keys: OS keystore handle or `chrome.storage` encrypted blob (never plaintext).
- Snapshots: Encrypted blobs in `blob://` or local file sandbox; metadata in `chrome.storage` or IndexedDB.
- Provider tokens: encrypted-at-rest; decrypted only in-memory for forwarding.

Security Invariants
- Private keys never leave the device unencrypted.
- Raw snapshot contents are never exposed to third-party adapters; only intended action outputs leave the client.

---

## Consent UI States & Flows (Frozen)

### UI States
- `idle` → no active request
- `request_received` → popup summoned with pending `SessionRequest`
- `details_view` → user inspects `appOrigin`, `requestedScopes`, persona, expiry
- `approved` → token created and delivered
- `denied` → request dismissed; no token
- `revoked` → previously issued token invalidated
- `expired` → token past TTL; must re-approve
- `error` → unrecoverable error (origin mismatch, missing user, etc.)

UI Model (popup)
```json
{
  "request": {"sessionId": "...", "appOrigin": "...", "requestedScopes": [], "requestedPersona": "..."},
  "user": {"userId": "...", "displayName": "..."},
  "decision": "approved|denied|revoked|null",
  "reason": "string|null"
}
```

### Flows
1) Connect
- Page → Content: `HIVE_CONNECT_REQUEST { payload: SessionRequest }`
- Content → Background: `HIVE_SESSION_REQUEST { payload: SessionRequest }`
- Background → Popup: `SHOW_SESSION_REQUEST`
- User approves → Popup → Background: `HIVE_CREATE_TOKEN { userId, sessionId, scopes, origin }`
- Background → Content (active tab): `HIVE_SESSION_APPROVED { token: ClientSignedToken }`
- User denies → Popup resets to `idle` (optionally emit `HIVE_SESSION_DENIED`)

2) Forward
- Page → Content: `HIVE_FORWARD_REQUEST { sessionToken, requestPayload }`
- Content → Background: `APP_FORWARD_REQUEST { sessionToken, requestPayload }`
- Background validates: `origin`, TTL, signature, `sub`, scopes
- Background → Content → Page: `HIVE_FORWARD_RESPONSE { ok, response|error }`

3) Revoke
- Popup or settings triggers revoke; background marks token/session as invalid
- Optional event: `HIVE_TOKEN_REVOKED { sessionId }`

### Error Conditions (non-exhaustive)
- `origin_mismatch`, `token_expired`, `invalid_signature`, `no_user`, `no_provider_token`, `scope_denied`
- Delivery: `HIVE_FORWARD_RESPONSE { ok:false, error: code }`

---

## Validation Rules (Frozen)

All forward requests MUST pass these checks in the background service before any provider call:

1. Origin
   - `sessionToken.origin` MUST equal the requesting page origin.
   - Reject if `document.location.origin` does not match.

2. TTL / Time
   - `exp > now_utc_seconds` and `(exp - iat) <= MAX_TTL`.
   - Clock skew tolerance ≤ 60s.

3. Signature
   - Verify signature over canonical payload: `sub|sessionId|scopes|iat|exp|origin`.
   - Reject on any mismatch or unsupported algorithm.

4. Subject Binding
   - `sessionToken.sub` MUST equal the stored `user.userId`.
   - User presence may be required for sensitive scopes (PIN/biometrics).

5. Scopes & Policy
   - All requested operations MUST be within `sessionToken.scopes`.
   - Apply local policy: autonomy level, spending caps, rate limits.

6. Revocation & Single-Use (optional hardening)
   - Check local revocation list for `sessionId`.
   - Optionally mark token as single-use for high-risk operations.

Validation Checklist
- [ ] origin matches
- [ ] exp valid, TTL within bounds
- [ ] signature valid
- [ ] sub matches stored user
- [ ] scopes authorized + policy allow
- [ ] not revoked / allowed for reuse

---

## Test Vectors & Threat Model (Frozen)

### Positive Test Vectors
- TV1: Valid token — origin matches, signature valid, scopes include `persona.use`, TTL 15 min, sub matches, not revoked.
- TV2: Minimal scopes — forward allowed only for `persona.use`; attempt to access `memory.read.full` blocked.

### Negative Test Vectors
- TVN1: `origin_mismatch` — token origin `https://a.example`, page origin `https://b.example` → reject.
- TVN2: `token_expired` — `exp < now` → reject.
- TVN3: `invalid_signature` — altered `scopes` after signing → reject.
- TVN4: `subject_mismatch` — token sub `user_x` but stored user `user_y` → reject.
- TVN5: `scope_denied` — request payload requires `transfer_asset` but scope absent → reject.
- TVN6: `revoked` — sessionId present in local revocation list → reject.
- TVN7: `no_provider_token` — user has no provider creds configured → reject.

### Threat Model (concise)
- Spoofed origin → Mitigation: strict origin match and token-bound origin.
- Token replay → Mitigation: short TTL, optional single-use, revocation list.
- Key exfiltration → Mitigation: OS keystore or AES-GMM with passphrase; never store plaintext keys.
- Scope escalation → Mitigation: signed scopes, server-side policy enforcement, deny by default.
- Data leakage → Mitigation: least exposure; never forward raw memories, only intended action outputs.
- CSRF/Clickjacking on consent → Mitigation: user presence (popup), explicit UI states, deny on hidden/iframes.

---

Files (copy into a directory like hive-extension/)

1) manifest.json

{
  "manifest_version": 3,
  "name": "Hive Container - Connector",
  "version": "0.1.0",
  "description": "Carry your AI persona into web apps. WalletConnect-style handshake for Hive Container.",
  "permissions": [
    "storage",
    "activeTab",
    "scripting",
    "tabs",
    "notifications"
  ],
  "host_permissions": [
    "<all_urls>"
  ],
  "background": {
    "service_worker": "dist/background.js"
  },
  "action": {
    "default_popup": "dist/popup.html",
    "default_title": "Hive Container"
  },
  "icons": {
    "16": "icons/icon16.png",
    "48": "icons/icon48.png",
    "128": "icons/icon128.png"
  },
  "content_scripts": [
    {
      "matches": ["<all_urls>"],
      "js": ["dist/contentScript.js"],
      "run_at": "document_start"
    }
  ],
  "web_accessible_resources": [
    {
      "resources": ["dist/popup.html", "icons/*"],
      "matches": ["<all_urls>"]
    }
  ]
}


---

2) src/types.ts

export type SessionRequest = {
  sessionId: string;
  appOrigin: string;
  requestedScopes: string[]; // e.g. ["persona.gpt", "memory.food"]
  requestedPersona?: string; // e.g. "gpt_poet"
  nonce?: string;
  createdAt?: number;
};

export type ClientSignedToken = {
  sessionId: string;
  sub: string; // user id
  scopes: string[];
  exp: number;
  iat: number;
  signature: string; // placeholder for client signature
};


---

3) src/background.ts (service worker)

/// <reference lib="webworker" />
import type { SessionRequest, ClientSignedToken } from "./types";

const HCP_GATEWAY_URL = "https://hcp-gateway.example.com"; // optional registry
const EXT_STORAGE_KEY = "hive_extension_user";
const SESSION_TTL_SECONDS = 60 * 30; // 30 minutes

type StoredUser = {
  userId: string;
  // NOTE: tokens should be stored encrypted. This is a placeholder only.
  providerTokens?: Record<string, string>;
  displayName?: string;
};

async function getStoredUser(): Promise<StoredUser | null> {
  return new Promise((res) =>
    chrome.storage.local.get([EXT_STORAGE_KEY], (items) => {
      res(items[EXT_STORAGE_KEY] ?? null);
    })
  );
}

async function setStoredUser(user: StoredUser) {
  return new Promise((res) =>
    chrome.storage.local.set({ [EXT_STORAGE_KEY]: user }, () => res(null))
  );
}

/**
 * Create a client-signed ephemeral token.
 * Replace the signing placeholder with your real crypto routine (WebCrypto / native).
 */
async function createClientSignedToken(
  userId: string,
  sessionId: string,
  scopes: string[]
): Promise<ClientSignedToken> {
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + SESSION_TTL_SECONDS;
  const payload = `${userId}|${sessionId}|${scopes.join(",")}|${iat}|${exp}`;
  // TODO: replace with secure signature using user's private key / WebCrypto
  const signature = btoa(await hashString(payload));
  return {
    sessionId,
    sub: userId,
    scopes,
    exp,
    iat,
    signature,
  };
}

async function hashString(s: string): Promise<string> {
  const enc = new TextEncoder();
  const buf = enc.encode(s);
  const hash = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/**
 * Handle incoming messages from content scripts or popup
 */
chrome.runtime.onMessage.addListener((msg: any, sender, sendResponse) => {
  if (msg?.type === "HIVE_SESSION_REQUEST") {
    // Relay to popup UI to show permission card
    // Contains: session request object + origin
    chrome.action.openPopup(); // open popup for UX (best-effort)
    chrome.runtime.sendMessage({ type: "SHOW_SESSION_REQUEST", payload: msg.payload });
    sendResponse({ ok: true });
    // keep channel open if needed
    return true;
  }

  if (msg?.type === "APP_FORWARD_REQUEST") {
    // The web app asks the extension to forward an LLM call to provider.
    // msg.payload = { sessionToken, requestPayload }
    handleAppForwardRequest(msg.payload)
      .then((resp) => sendResponse({ ok: true, response: resp }))
      .catch((err) => sendResponse({ ok: false, error: String(err) }));
    return true;
  }

  sendResponse({ ok: false, error: "unknown_message" });
});

/**
 * Forward a request to the external LLM provider using locally stored provider tokens.
 * IMPORTANT: do NOT persist response. This function returns the response to the caller and discards it.
 */
async function handleAppForwardRequest(payload: { sessionToken: ClientSignedToken; requestPayload: any }) {
  const { sessionToken, requestPayload } = payload;
  const user = await getStoredUser();
  if (!user) throw new Error("no_user");

  // Validate token (basic)
  if (sessionToken.sub !== user.userId) throw new Error("invalid_token_sub");
  if (sessionToken.exp < Math.floor(Date.now() / 1000)) throw new Error("token_expired");

  // Use the user's provider token - placeholder chooses 'openai' token
  const providerKey = user.providerTokens?.["openai"];
  if (!providerKey) throw new Error("no_provider_token");

  // Forward to provider (example: OpenAI)
  const response = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${providerKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify(requestPayload)
  });

  const json = await response.json();
  // Optionally: store only metadata/hashes in local audit log (never store raw content)
  // Example: compute sha256 of response text and store timestamped hash
  try {
    const textRep = JSON.stringify(json);
    const hash = await hashString(textRep);
    // Append to ephemeral in-memory audit (or lightweight local persist)
    chrome.storage.local.get(["hive_audit"], (items) => {
      const logs = items["hive_audit"] ?? [];
      logs.push({ sessionId: sessionToken.sessionId, hash, ts: Date.now() });
      chrome.storage.local.set({ hive_audit: logs });
    });
  } catch (e) {
    // ignore audit failures
  }

  return json;
}

/**
 * Example admin function to set user (developer convenience)
 */
chrome.runtime.onMessage.addListener((msg, sender, respond) => {
  if (msg?.type === "HIVE_SET_USER") {
    setStoredUser(msg.payload).then(() => respond({ ok: true }));
    return true;
  }
});


---

4) src/contentScript.ts

// Content script runs on pages and can detect a "Connect Hive" button or accept postMessage from page
// It listens for window.postMessage handshake from web apps and forwards to the extension background

window.addEventListener("message", (evt) => {
  // Only accept messages from the same origin or keys you trust
  if (!evt.data || evt.data.source !== "HIVE_CONNECT_REQUEST") return;

  // Example payload: { sessionId, requestedScopes, requestedPersona }
  const payload = evt.data.payload;
  // Send to background to summon popup / permission
  chrome.runtime.sendMessage({ type: "HIVE_SESSION_REQUEST", payload }, (resp) => {
    // Notify the page that the request was relayed
    window.postMessage({ source: "HIVE_CONNECT_RELAYED", payload: { ok: !!resp?.ok } }, window.origin);
  });
}, false);

// helper: allow page to request forward to provider via extension by posting a message
window.addEventListener("message", (evt) => {
  if (!evt.data || evt.data.source !== "HIVE_FORWARD_REQUEST") return;
  // { sessionToken, requestPayload }
  chrome.runtime.sendMessage({ type: "APP_FORWARD_REQUEST", payload: evt.data.payload }, (resp) => {
    // send result back to page
    window.postMessage({ source: "HIVE_FORWARD_RESPONSE", payload: resp }, window.origin);
  });
});


---

5) src/popup.html

<!doctype html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Hive Connector</title>
    <meta name="viewport" content="width=device-width,initial-scale=1" />
    <style>
      body { font-family: system-ui, sans-serif; padding:12px; width:320px; }
      .session { border: 1px solid #ddd; padding:8px; margin-bottom:8px; border-radius:6px; }
      .btn { padding:8px 10px; border-radius:6px; cursor:pointer; }
      .approve { background:#0b6; color:#fff; border:none; }
      .deny { background:#f44; color:#fff; border:none; margin-left:8px; }
    </style>
  </head>
  <body>
    <h3>Hive Connector</h3>
    <div id="session-list">No session requests</div>
    <hr/>
    <h4>User</h4>
    <div id="user-info">Not set</div>
    <button id="set-sample-user">Set sample user (dev)</button>
    <script src="popup.js"></script>
  </body>
</html>


---

6) src/popup.ts

import type { SessionRequest, ClientSignedToken } from "./types";

declare const chrome: any;

const sessionList = document.getElementById("session-list")!;
const userInfo = document.getElementById("user-info")!;
const setSample = document.getElementById("set-sample-user")!;

let pendingSession: SessionRequest | null = null;

function renderUser() {
  chrome.storage.local.get(["hive_extension_user"], (items: any) => {
    const user = items.hive_extension_user;
    if (!user) {
      userInfo.textContent = "No user stored. (Use dev button)";
    } else {
      userInfo.textContent = `${user.displayName ?? user.userId}`;
    }
  });
}

chrome.runtime.onMessage.addListener((msg: any) => {
  if (msg?.type === "SHOW_SESSION_REQUEST") {
    pendingSession = msg.payload as SessionRequest;
    renderSession();
  }
});

function renderSession() {
  if (!pendingSession) {
    sessionList.innerHTML = "<i>No session request</i>";
    return;
  }
  sessionList.innerHTML = "";
  const div = document.createElement("div");
  div.className = "session";
  div.innerHTML = `
    <strong>App:</strong> ${pendingSession.appOrigin || "unknown"} <br/>
    <strong>Persona:</strong> ${pendingSession.requestedPersona || "default"} <br/>
    <strong>Scopes:</strong> ${pendingSession.requestedScopes.join(", ")}
  `;
  const approveBtn = document.createElement("button");
  approveBtn.className = "btn approve";
  approveBtn.textContent = "Approve";
  approveBtn.onclick = async () => {
    await approveSession();
  };

  const denyBtn = document.createElement("button");
  denyBtn.className = "btn deny";
  denyBtn.textContent = "Deny";
  denyBtn.onclick = () => {
    pendingSession = null;
    renderSession();
  };

  div.appendChild(approveBtn);
  div.appendChild(denyBtn);
  sessionList.appendChild(div);
}

async function approveSession() {
  if (!pendingSession) return;
  // Generate client-signed token by asking background to sign
  const user = (await new Promise((res) => chrome.storage.local.get(["hive_extension_user"], (i:any) => res(i["hive_extension_user"])))) as any;
  if (!user) {
    alert("No user set. Use dev button to set a sample user in this skeleton.");
    return;
  }

  // Call background "create token" flow by sending a message that background handles
  const signedToken = await new Promise<ClientSignedToken>((res) => {
    chrome.runtime.sendMessage({ type: "HIVE_CREATE_TOKEN", payload: { userId: user.userId, sessionId: pendingSession!.sessionId, scopes: pendingSession!.requestedScopes } }, (resp: any) => {
      res(resp.token);
    });
  });

  // Send token back to the origin page via window.postMessage (we use content script channel)
  // We need to identify the tab to send message to — background should have tracked the origin tab, but for simplicity we'll post to all frames
  // Use messaging: content script will be listening for HIVE_CONNECT_APPROVED events
  chrome.tabs.query({ active: true, currentWindow: true }, (tabs: any[]) => {
    if (!tabs || tabs.length === 0) return;
    chrome.tabs.sendMessage(tabs[0].id, { type: "HIVE_SESSION_APPROVED", payload: { token: signedToken } });
  });

  pendingSession = null;
  renderSession();
}

setSample.addEventListener("click", () => {
  // Dev helper: set a sample user and provider token (placeholder)
  const sampleUser = { userId: "larry_omakh", displayName: "Larry Omakh", providerTokens: { openai: "REPLACE_WITH_REAL_TOKEN" } };
  chrome.storage.local.set({ hive_extension_user: sampleUser }, () => {
    renderUser();
    alert("Sample user stored in extension storage (dev). Replace token in real flow.");
  });
});

renderUser();
renderSession();

> Note: The popup delegates token creation to background for security; we use a HIVE_CREATE_TOKEN message — you’ll implement that in background (or adjust to create the token directly in background).




---

7) Build / bundling notes

This skeleton assumes you’ll transpile TypeScript to JavaScript and output into dist/ folder. Use a simple bundler (esbuild/webpack/tsc) to compile:

src/background.ts → dist/background.js

src/contentScript.ts → dist/contentScript.js

src/popup.ts → dist/popup.js and include it in popup.html


Add icons/ with placeholder PNGs (16/48/128) or remove icon references in manifest.json temporarily.


Example minimal esbuild commands:

npx esbuild src/background.ts --bundle --platform=browser --outfile=dist/background.js
npx esbuild src/contentScript.ts --bundle --platform=browser --outfile=dist/contentScript.js
npx esbuild src/popup.ts --bundle --platform=browser --outfile=dist/popup.js


---

How the web app should call the extension (page-side snippet)

Place this in any demo web app to request a Hive connect:

<script>
  // create session request (ideally via your HCP server to avoid spoofing)
  const sessionRequest = {
    sessionId: "hive_" + Math.random().toString(36).slice(2,10),
    requestedScopes: ["persona.gpt","memory.food"],
    requestedPersona: "gpt_poet",
    appOrigin: window.location.origin,
    createdAt: Date.now()
  };

  // Post to the page so content script picks it up
  window.postMessage({ source: "HIVE_CONNECT_REQUEST", payload: sessionRequest }, window.origin);

  // Listen for approval and token
  window.addEventListener("message", (evt) => {
    if (evt.data && evt.data.source === "HIVE_SESSION_APPROVED") {
      const token = evt.data.payload.token;
      // Use token + forward your LLM payload via the extension content script
      // Example: request the content script to forward
      window.postMessage({ source: "HIVE_FORWARD_REQUEST", payload: { sessionToken: token, requestPayload: {/* LLM request body */} } }, window.origin);
    }
  }, false);
</script>


---

Important security & production notes (read carefully)

Do NOT store provider tokens in plaintext. The sample dev flow stores providerTokens as a placeholder. In production: use platform encryption (Chrome chrome.storage with OS key, or WebCrypto encrypt with user passphrase).

Replace the createClientSignedToken placeholder with a secure signature scheme based on a user-held private key (WebCrypto SubtleCrypto.importKey + sign) or native key store.

Implement strict origin checks and anti-forgery validation on the page messages (validate appOrigin, verify session came from HCP registry).

Use short TTL for tokens and require re-approval for sensitive scopes.

Consider requiring user authentication to open the popup and sign tokens (PIN, OS biometrics).

Add robust error handling & graceful failures if the user goes offline.



---

Next steps I can produce immediately (pick any)

1. Implement the HIVE_CREATE_TOKEN message handler in background.ts with a secure WebCrypto signing example.


2. A minimal HCP Gateway mock server (Node.js + Express) to generate session_uri and verify client-signed tokens.


3. An example demo web app that shows the full flow end-to-end (request -> approve -> forward -> show LLM response).


4. A concise README with build scripts and deployment instructions.



Which one do you want me to add right now?


