

1. Architecture & security design (how it works end-to-end).
2. Concrete API spec (OpenAPI summary + endpoints).
3. Express backend code (auth/session handler, persona endpoints, JWT signing).
4. Chrome extension changes (popup, content script, background worker) to:

   * initiate sign-in,
   * capture session/token **safely** (preferred: OAuth; fallback: session detection),
   * request persona extraction,
   * encrypt & store persona locally, and
   * push persona to site adapters.
5. Persona compression & embedding utilities (Node + Python examples).
6. Secure local storage helpers (WebCrypto AES-GCM) for extension.
7. Adapter example (how a third-party site accepts a Hive persona and injects into its AI).
8. Integration & deployment steps, and checklist for security/compliance.

I’m delivering code + designs here so you can commit directly. Copy the files into your repo structure (`reference-mvp/` or `extension/` folders) or tell me to prepare a PR-ready patch and I’ll produce the exact diffs.

---

# 1) High-level architecture (merged)

User flow (summary)

1. User opens extension popup → chooses **Sign in with ChatGPT (OpenAI)**.
2. Extension opens the provider auth page (preferred: official OAuth if OpenAI supports it). If provider OAuth is unavailable, extension opens `chat.openai.com` login page and waits for session (fallback).
3. Once authenticated, extension obtains a short-lived **session token** (via secure OAuth callback from backend OR via `chrome.cookies` + host permission in fallback) — **never** collects raw password.
4. Extension calls Hive Bridge `/persona/extract` with the session token OR instructs Bridge to fetch profile on behalf of user.
5. Bridge (server) verifies the token (or validates session by contacting provider) and extracts user settings via provider APIs (or via scraping endpoints where allowed) — **only permitted fields**.
6. Bridge returns a compressed `PersonaSnapshot` (or saves it and returns a signed `ClientSignedToken`).
7. Extension encrypts and stores the snapshot locally (AES-GCM via WebCrypto) and can optionally store it server-side (encrypted).
8. When the user visits a partner AI site and approves, extension negotiates handshake (domain ↔ persona scopes) and either:

   * PUSH: sends compressed persona (signed) to site via `POST /receivePersona` and the site’s adapter accepts and maps into its assistant; or
   * PROMPT: synthesizes a provider-specific initial system prompt embedding the persona and inserts it into the target AI assistant input (via content script / adapter).

Security & privacy notes (top-level)

* Use OAuth or provider-approved flows when possible.
* If session cookie capture is used, require explicit per-domain permission and show clear consent.
* Encrypt persona at rest on device. If uploaded to cloud, encrypt and store minimal fields.
* Audit logs of shares and ability to revoke per-site must be available.
* Default minimal sharing scope; user explicitly opts in to richer fields.

---

# 2) API Spec (summary / OpenAPI snippets)

Key endpoints (Bridge):

* `POST /auth/start` — returns URL for provider sign-in (OAuth).
* `GET /auth/callback` — provider redirects here; Bridge issues short-lived JWT for the extension.
* `POST /persona/extract` — (auth: Bridge JWT or provider session) extract persona from provider & compress it.
* `POST /persona/push` — upload signed compressed persona to Bridge (optional).
* `GET /persona/:userId` — fetch persona (auth + scope).
* `POST /handshake` — extension requests handshake for domain (user consents).
* `POST /adapter/accept` — third-party site verifies signed token and pulls persona.

I'll provide an OpenAPI summary in code blocks below.

---

# 3) Backend — Express (reference code)

This is a reference bridge server that supports OAuth initiation and persona extraction endpoints. Replace the provider specifics with the actual provider endpoints (OpenAI OAuth if/when available).

`server.mjs` (bridge main) — **notes** included inline.

```js
/**
 * reference-bridge/server.mjs
 *
 * Minimal bridge with:
 * - /auth/start  -> build provider auth URL
 * - /auth/callback -> provider redirects here (example)
 * - /persona/extract -> extract persona (mocked for now)
 * - /handshake -> record domain consent
 *
 * This is a reference. Replace provider OAuth endpoints and persona-fetch logic
 * with actual provider APIs or verified mechanisms.
 */

import express from "express";
import dotenv from "dotenv";
import cors from "cors";
import bodyParser from "body-parser";
import jwt from "jsonwebtoken";
import fetch from "node-fetch"; // or global fetch on modern node

dotenv.config();
const app = express();
app.use(cors());
app.use(bodyParser.json());

// In production store secrets securely
const JWT_SECRET = process.env.JWT_SECRET || "dev-secret-do-not-use";
const PROVIDER_CLIENT_ID = process.env.PROVIDER_CLIENT_ID || "client-id";
const PROVIDER_CLIENT_SECRET = process.env.PROVIDER_CLIENT_SECRET || "client-secret";
const REDIRECT_URI = process.env.REDIRECT_URI || "http://localhost:4000/auth/callback";

const HANDSHAKES = [];
const PERSONAS = new Map();

/**
 * 1) Start auth (returns provider login URL)
 *    If provider supports OAuth, build URL with state.
 */
app.post("/auth/start", (req, res) => {
  const state = Math.random().toString(36).slice(2);
  // Example OAuth URL (replace with provider's)
  const authUrl = `https://chat.openai.com/oauth/authorize?response_type=code&client_id=${PROVIDER_CLIENT_ID}&redirect_uri=${encodeURIComponent(REDIRECT_URI)}&scope=profile%20settings&state=${state}`;
  // Save state in short-lived store if required
  res.json({ authUrl, state });
});

/**
 * 2) OAuth callback (provider redirects here with code)
 *    Exchange code for provider token, then issue our Bridge JWT to the extension
 *
 *    Note: Many providers (including OpenAI) may not expose full user-profile endpoints.
 *    The callback here is a template — adapt to the actual provider.
 */
app.get("/auth/callback", async (req, res) => {
  const code = req.query.code;
  const state = req.query.state;
  if (!code) return res.status(400).send("Missing code");
  // Exchange code for access token (mock)
  // Replace with provider token endpoint call
  /*
  const tokenResp = await fetch('https://provider.example.com/oauth/token', {
    method: 'POST',
    headers: {'Content-Type':'application/x-www-form-urlencoded'},
    body: `grant_type=authorization_code&code=${code}&redirect_uri=${encodeURIComponent(REDIRECT_URI)}&client_id=${PROVIDER_CLIENT_ID}&client_secret=${PROVIDER_CLIENT_SECRET}`
  });
  const tokenJson = await tokenResp.json();
  const providerAccessToken = tokenJson.access_token;
  */
  // For reference server: create a fake providerAccessToken
  const providerAccessToken = "demo-provider-token-" + Math.random().toString(36).slice(2);

  // Issue a short-lived bridge JWT that the extension can use
  const bridgeToken = jwt.sign({ providerAccessToken, sub: "demo-user" }, JWT_SECRET, { expiresIn: "15m" });

  // In real flow, redirect back to extension/webapp with token (use postMessage or redirect to deep link)
  // For simple testing show token JSON
  res.json({ bridgeToken });
});

/**
 * 3) Persona extract: extension sends bridge JWT, optional provider session.
 *    Bridge validates JWT, then extracts persona from provider (mock).
 */
app.post("/persona/extract", (req, res) => {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ error: "Missing Authorization" });
  const token = auth.split(" ")[1];
  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    // Use decoded.providerAccessToken to fetch provider profile (mock behavior below)
    // In real system call provider APIs with providerAccessToken to fetch allowed fields.
    const persona = {
      userId: decoded.sub || "demo-user",
      summary: "Prefers concise, technical answers. Likes Python and ML.",
      tone: "analytical",
      expertise: ["ml", "python", "systems"],
      softPreferences: { verbosity: "low" },
      lastUpdated: Date.now()
    };
    // compress persona (in real system run embedding/compression)
    PERSONAS.set(persona.userId, persona);
    // sign persona for transport (ClientSignedToken)
    const signed = jwt.sign({ snapshot: persona }, JWT_SECRET, { expiresIn: "1h" });
    res.json({ persona, signedToken: signed });
  } catch (e) {
    console.error(e);
    return res.status(401).json({ error: "Invalid token" });
  }
});

/**
 * 4) Handshake: record user consent for domain
 */
app.post("/handshake", (req, res) => {
  const { domain, userId, scopes } = req.body || {};
  if (!domain || !userId) return res.status(400).json({ error: "domain & userId required" });
  HANDSHAKES.push({ domain, userId, scopes, ts: Date.now() });
  res.json({ ok: true });
});

/**
 * 5) Adapter verification endpoint (third-party site calls to verify signed persona)
 */
app.post("/adapter/verify", (req, res) => {
  const { signedToken } = req.body || {};
  try {
    const decoded = jwt.verify(signedToken, JWT_SECRET);
    res.json({ ok: true, snapshot: decoded.snapshot });
  } catch (e) {
    res.status(401).json({ ok: false, error: e.message });
  }
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log("Bridge up on", PORT));
```

> **Notes:** replace provider OAuth URLs and token exchange with actual provider endpoints. Many LLM vendors may not provide OAuth for end-user profile fetch; use the provider's recommended integration path or the fallback session capture approach (explained later).

---

# 4) Chrome extension changes (reference)

We provide three key pieces for the extension:

A. `popup.js` — trigger sign-in and call `/auth/start`.
B. `background.js` — open auth window and listen for messages/redirects.
C. `content.js` — injection UI (Hive Card) and push persona to the page (adapter).

### a) Popup: initiate sign-in

`popup/popup.html` (simple):

```html
<!doctype html>
<html>
<head><meta charset="utf-8"><title>Hive</title></head>
<body>
  <button id="signin">Sign in with ChatGPT</button>
  <button id="importPersona">Import Persona</button>
  <script src="popup.js"></script>
</body>
</html>
```

`popup/popup.js`:

```js
document.getElementById('signin').addEventListener('click', async () => {
  // call bridge to start auth
  const r = await fetch('http://localhost:4000/auth/start', { method: 'POST' });
  const j = await r.json();
  const authUrl = j.authUrl;
  // open authUrl in a new window (background will manage callback)
  chrome.runtime.sendMessage({ action: 'openAuth', authUrl });
});

document.getElementById('importPersona').addEventListener('click', async () => {
  // request bridge to extract persona (requires the bridge JWT to be stored)
  const { bridgeToken } = await new Promise(done => chrome.storage.local.get(['bridgeToken'], done));
  if (!bridgeToken) return alert('No bridge token, sign in first');
  const res = await fetch('http://localhost:4000/persona/extract', {
    method: 'POST',
    headers: { 'Authorization': 'Bearer ' + bridgeToken, 'Content-Type': 'application/json' }
  });
  const j = await res.json();
  if (j.persona) {
    // encrypt & store locally (use extension helper)
    chrome.storage.local.set({ hivePersona: j.persona, signedPersona: j.signedToken }, () => {
      alert('Persona imported and stored');
    });
  } else {
    alert('Failed extracting persona');
  }
});
```

### b) Background: open auth and receive token

`background.js`:

```js
chrome.runtime.onMessage.addListener((msg, sender) => {
  if (msg.action === 'openAuth') {
    const authUrl = msg.authUrl;
    // open a new window for auth
    chrome.windows.create({ url: authUrl, type: 'popup', width: 900, height: 700 }, (win) => {
      // Poll or listen for redirect to /auth/callback with bridge token (in real flow)
      // Simpler test flow: instruct user to copy bridge token from the redirect page, or have an explicit message from server to extension via websockets.
    });
  }
});
```

> Important: real OAuth redirect handling ideally sends the token to the extension via a registered deep link (e.g., `chrome-extension://<id>/auth.html`) or the backend redirects to a page that uses `window.postMessage` or a one-time code that the extension polls for. Implement a secure state parameter and validate it.

### c) Content script: Hive Card & push persona

`content.js`:

```js
// Inject small Hive card when site appears to have an AI
(function(){
  if (document.querySelector('#hive-card')) return;
  const card = document.createElement('div');
  card.id = 'hive-card';
  Object.assign(card.style, {
    position: 'fixed', right: '18px', bottom: '18px',
    padding: '10px 12px', borderRadius: '12px',
    background: '#ff8800', color: '#fff', zIndex: 999999, cursor: 'pointer'
  });
  card.textContent = '🐝 Use my Hive persona';
  card.onclick = async () => {
    // ask user for consent for this domain
    const ok = confirm('Share your persona with ' + location.hostname + '?');
    if (!ok) return;
    // read persona from storage and send to site adapter endpoint
    chrome.storage.local.get(['signedPersona','hivePersona'], async (r) => {
      if (!r.signedPersona) { alert('No persona found. Import first.'); return; }
      // POST to site if it provides /hive/receive or /api/receivePersona
      try {
        const endpoint = location.origin + '/hive/receivePersona';
        const res = await fetch(endpoint, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ signedPersona: r.signedPersona })
        });
        if (res.ok) alert('Persona delivered (adapter may process it).');
        else {
          // fallback: inject prompt into page (requires site compatibility)
          alert('Adapter not found - will attempt prompt injection (fallback).');
          injectPrompt(r.hivePersona);
        }
      } catch (e) {
        console.error(e);
        injectPrompt(r.hivePersona);
      }
    });
  };
  document.body.appendChild(card);

  function injectPrompt(persona) {
    // Example: find a text area and prefill a system message. This is fragile.
    const ta = document.querySelector('textarea') || document.querySelector('input[type=text]');
    if (ta) {
      const system = `SYSTEM: Use persona -> ${JSON.stringify(persona).slice(0,500)}`;
      ta.value = system + "\n\n" + ta.value;
      ta.focus();
    } else alert('No writable input found to inject prompt.');
  }
})();
```

> Note: Prompt injection fallback is fragile and site-specific. Preferred path is to have the site implement a `POST /hive/receivePersona` adapter endpoint or follow an agreed adapter API.

---

# 5) Persona compression & embedding

You want a small payload and optionally an embedding vector.

### Node compressor (already included earlier) — improved:

`persona_utils.js`:

```js
export function compressPersona(raw) {
  const out = {
    userId: raw.userId || 'anon',
    summary: (raw.summary || '').slice(0, 200),
    tone: raw.tone || 'neutral',
    expertise: (raw.expertise || []).slice(0, 8),
    persistentFacts: sanitizeFacts(raw.persistentFacts || {}),
    softPreferences: raw.softPreferences || {},
    lastUpdated: Date.now()
  };
  // size guard
  const s = JSON.stringify(out);
  if (s.length > 2048) {
    out.summary = out.summary.slice(0, 100);
  }
  return out;
}
function sanitizeFacts(f) {
  const out = {};
  for (const [k,v] of Object.entries(f).slice(0,10)) out[k] = String(v).slice(0,120);
  return out;
}
```

### Embedding (Python fallback)

`embed_example.py` (from previous):

```python
def simple_hash_embedding(text, dim=128):
    vec = [0]*dim
    for i, ch in enumerate(text[:1024]):
        vec[i % dim] += ord(ch)
    s = sum(abs(x) for x in vec) or 1
    return [x / s for x in vec]
```

In production: compute OpenAI or local model embeddings then reduce dimension via PCA to 128 and quantize to int8 for transport.

---

# 6) Secure local storage — WebCrypto (extension helper)

`extension_helpers/storage.js` (complete example):

```js
const enc = new TextEncoder();
const dec = new TextDecoder();

export async function deriveKeyFromPassword(password, salt=null) {
  salt = salt || crypto.getRandomValues(new Uint8Array(16));
  const baseKey = await crypto.subtle.importKey('raw', enc.encode(password), 'PBKDF2', false, ['deriveKey']);
  const key = await crypto.subtle.deriveKey({
    name: 'PBKDF2', salt,
    iterations: 200000,
    hash: 'SHA-256'
  }, baseKey, { name: 'AES-GCM', length: 256 }, true, ['encrypt', 'decrypt']);
  return { key, salt };
}

export async function encryptObj(obj, key) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const data = enc.encode(JSON.stringify(obj));
  const ct = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, data);
  return { ct: arrayBufferToBase64(ct), iv: arrayBufferToBase64(iv) };
}

export async function decryptObj(payload, key) {
  const ct = base64ToArrayBuffer(payload.ct);
  const iv = base64ToArrayBuffer(payload.iv);
  const pt = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, ct);
  return JSON.parse(dec.decode(pt));
}

function arrayBufferToBase64(buf) {
  return btoa(String.fromCharCode(...new Uint8Array(buf)));
}
function base64ToArrayBuffer(b64) {
  const s = atob(b64);
  const arr = new Uint8Array(s.length);
  for (let i=0;i<s.length;i++) arr[i]=s.charCodeAt(i);
  return arr.buffer;
}
```

Usage pattern:

* Ask user for a passphrase once (or use account-based key), derive key, encrypt persona before `chrome.storage.local.set({hivePersonaEncrypted: ...})`.
* On load, derive key and decrypt.

---

# 7) Adapter example — how site receives persona

Third-party site endpoint `/hive/receivePersona` (Node):

```js
// site adapter - receive persona and map into its AI assistant
import express from 'express';
import bodyParser from 'body-parser';
import jwt from 'jsonwebtoken'; // to verify signed persona (bridge must sign with known key)
const app = express();
app.use(bodyParser.json());

const BRIDGE_PUBLIC_KEY = process.env.BRIDGE_PUBLIC_KEY || 'bridge-public-key-placeholder';

app.post('/hive/receivePersona', (req, res) => {
  const { signedPersona } = req.body || {};
  if (!signedPersona) return res.status(400).json({ error: 'signedPersona required' });
  try {
    // verify using bridge public key (if using asymmetric signing)
    const decoded = jwt.verify(signedPersona, BRIDGE_PUBLIC_KEY);
    const persona = decoded.snapshot;
    // Map persona to local assistant config
    // Example: set system prompt, tweak tone, etc.
    // Save to session or respond with confirmation
    res.json({ ok: true, persona });
  } catch (e) {
    res.status(401).json({ error: 'invalid token', details: e.message });
  }
});

app.listen(7000, ()=>console.log('Adapter listening on 7000'));
```

If the site cannot accept POST, use content-script prompt injection with caution.

---

# 8) Implementation checklist & staged rollout

Phase 0 — local dev (reference)

* [x] Express bridge skeleton with `/auth/start`, `/auth/callback`, `/persona/extract`, `/handshake`.
* [x] Chrome extension content card, popup, background skeleton.
* [x] Persona compressor & embedding example.
* [x] WebCrypto storage example.
* [x] Adapter example.

Phase 1 — hardened demo

* [ ] Replace mock OAuth links with real provider OAuth (OpenAI / other).
* [ ] Implement secure redirect flow to extension (deep link or polling with state code).
* [ ] Implement proper JWT signing with asymmetric keys; expose public key to adapters.
* [ ] Implement per-domain consent UI & storage of handshake logs.
* [ ] Ensure extension uses `optional_permissions` and requests host permission at runtime.

Phase 2 — partner integrability

* [ ] Publish OpenAPI + SDKs for adapters.
* [ ] Ship adapter npm package for quick site integration.
* [ ] Create a consent dashboard for users to view/revoke domain shares.

Phase 3 — scale & compliance

* [ ] Security audit, privacy policy, legal review for token economy integration.
* [ ] Add telemetry opt-in with anonymized metrics.

---

# 9) Security & Privacy: important cautions (do this now)

* **Never collect passwords.** Use OAuth or session tokens only. If you capture cookies, do so only with explicit per-domain permission and explain exactly what is captured.
* **Short-lived tokens** only: issue short Bridge tokens and rotate/expire them.
* **Signed persona tokens**: Bridge should sign persona snapshots with private key; adapters verify with public key.
* **Minimal fields**: default to share `tone`, `summary`, `expertise`. Avoid PII like emails, payment data.
* **Audit & revoke**: build UI to list when and where persona was shared; allow revocation and deletion.



