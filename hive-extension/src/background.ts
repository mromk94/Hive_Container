import type { SessionRequest, ClientSignedToken } from "./types";
import { signStringES256 } from "./crypto";
import { isAllowedOrigin } from "./config";
import { getRegistry, getPreferredModel, setPreferredModel, getProviderToken, getPersonaProfile } from "./registry";
declare const chrome: any;

const EXT_STORAGE_KEY = "hive_extension_user";
const SESSION_TTL_SECONDS = 60 * 30; // 30 minutes
const USED_TOKEN_KEY = "hive_used_tokens"; // store base64url signatures
const REVOKED_SESSIONS_KEY = "hive_revoked_sessions"; // store sessionIds
const BUILD_INFO = "hive-ext build: 2025-10-31 gemini-v1 latest + registry";

async function getStoredUser(): Promise<any | null> {
  return new Promise((res) => chrome.storage.local.get([EXT_STORAGE_KEY], (items: Record<string, any>) => res(items[EXT_STORAGE_KEY] ?? null)));
}

// Small helper to bound latency on outbound requests
async function fetchJsonWithTimeout(url: string, init: RequestInit, timeoutMs: number): Promise<{ resp: Response; json: any }> {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const resp = await fetch(url, { ...init, signal: ctrl.signal });
    let json: any = null;
    try { json = await resp.json(); } catch { json = { text: await resp.text() }; }
    return { resp, json };
  } finally {
    clearTimeout(t);
  }
}
 

function mapOpenAIToClaudeBody(req: any): { model: string; messages: any[]; max_tokens: number } {
  let model: string = typeof req?.model === "string" && req.model.startsWith("claude") ? req.model : "claude-3-5-sonnet-latest";
  const messages: any[] = Array.isArray(req?.messages) ? req.messages : [];
  const mapped = messages.map((m) => ({ role: m.role === "assistant" ? "assistant" : "user", content: toStringContent(m.content) }));
  return { model, messages: mapped, max_tokens: 1024 };
}

function toStringContent(content: any): string {
  if (!content) return "";
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content.map((c) => (typeof c === "string" ? c : c?.text || "")).join("\n");
  }
  if (typeof content === "object" && content.text) return content.text;
  try { return JSON.stringify(content); } catch { return String(content); }
}

function mapOpenAIToGeminiBody(req: any): { model: string; contents: any[] } {
  let model: string = typeof req?.model === "string" && req.model.startsWith("gemini") ? req.model : "gemini-1.5-flash-latest";
  if (model === "gemini-1.5-flash") model = "gemini-1.5-flash-latest";
  if (model === "gemini-1.5-pro") model = "gemini-1.5-pro-latest";
  const messages: any[] = Array.isArray(req?.messages) ? req.messages : [];
  const contents = messages.map((m) => ({
    role: m.role === "assistant" ? "model" : "user",
    parts: [{ text: toStringContent(m.content) }],
  }));
  return { model, contents };
}

async function getStringArray(key: string): Promise<string[]> {
  return new Promise((res) => chrome.storage.local.get([key], (items: Record<string, any>) => res(Array.isArray(items[key]) ? items[key] : [])));
}

async function addToStringArray(key: string, value: string): Promise<void> {
  const arr = await getStringArray(key);
  if (!arr.includes(value)) arr.push(value);
  return new Promise((res) => chrome.storage.local.set({ [key]: arr }, () => res()));
}

async function isTokenUsed(signature?: string): Promise<boolean> {
  if (!signature) return false;
  const used = await getStringArray(USED_TOKEN_KEY);
  return used.includes(signature);
}

async function markTokenUsed(signature?: string): Promise<void> {
  if (!signature) return;
  await addToStringArray(USED_TOKEN_KEY, signature);
}

async function isSessionRevoked(sessionId?: string): Promise<boolean> {
  if (!sessionId) return false;
  const revoked = await getStringArray(REVOKED_SESSIONS_KEY);
  return revoked.includes(sessionId);
}

async function revokeSession(sessionId: string): Promise<void> {
  await addToStringArray(REVOKED_SESSIONS_KEY, sessionId);
}

async function createClientSignedToken(userId: string, sessionId: string, scopes: string[], origin?: string): Promise<ClientSignedToken> {
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + SESSION_TTL_SECONDS;
  const payload = `${userId}|${sessionId}|${scopes.join(",")}|${iat}|${exp}|${origin ?? ""}`;
  const { alg, sig } = await signStringES256(payload);
  const signature = sig;
  // singleUse flag will be attached by caller payload; default false here
  return { sessionId, sub: userId, scopes, exp, iat, signature, alg, origin };
}

// Generate runtime action icon (black & gold bee+brain theme)
function makeIconImageData(size: number): ImageData | null {
  try {
    const oc = new OffscreenCanvas(size, size);
    const ctx = oc.getContext('2d') as any;
    if (!ctx) return null;
    // Background
    ctx.fillStyle = '#0a0a0a';
    ctx.fillRect(0,0,size,size);
    // Gold accents
    const gold = '#d4af37';
    // Bee stripes
    ctx.fillStyle = gold;
    for (let i=0;i<3;i++){
      const y = Math.floor(size*(0.30 + i*0.15));
      ctx.fillRect(Math.floor(size*0.12), y, Math.floor(size*0.76), Math.floor(size*0.06));
    }
    // Brain swirl (arc)
    ctx.strokeStyle = gold;
    ctx.lineWidth = Math.max(1, Math.floor(size*0.06));
    ctx.beginPath();
    ctx.arc(size*0.5, size*0.45, size*0.22, 0.8*Math.PI, 1.9*Math.PI);
    ctx.stroke();
    // Small hex (honeycomb)
    function hex(cx:number, cy:number, r:number){
      ctx.beginPath();
      for (let k=0;k<6;k++){
        const a = (Math.PI/3)*k;
        const x = cx + r*Math.cos(a);
        const y = cy + r*Math.sin(a);
        if (k===0) ctx.moveTo(x,y); else ctx.lineTo(x,y);
      }
      ctx.closePath();
    }
    ctx.lineWidth = Math.max(1, Math.floor(size*0.03));
    hex(size*0.78, size*0.26, size*0.10);
    ctx.stroke();
    // Glow
    ctx.shadowColor = gold;
    ctx.shadowBlur = Math.max(2, Math.floor(size*0.1));
    ctx.fillStyle = 'rgba(212,175,55,0.15)';
    ctx.beginPath(); ctx.arc(size*0.5, size*0.5, size*0.38, 0, Math.PI*2); ctx.fill();
    // Export
    const img = ctx.getImageData(0,0,size,size);
    return img;
  } catch { return null; }
}

function setActionIcons(){
  try {
    const sizes = [16,32,48,128];
    const dict: Record<string, ImageData> = {} as any;
    for (const s of sizes){
      const img = makeIconImageData(s);
      if (img) dict[String(s)] = img;
    }
    if (Object.keys(dict).length) chrome.action.setIcon({ imageData: dict });
  } catch {}
}

chrome.runtime.onMessage.addListener((msg: any, _sender: any, sendResponse: (resp: any) => void) => {
  // Ensure icon set when background activates
  setActionIcons();
  if (msg?.type === "HIVE_SESSION_REQUEST") {
    (async () => {
      await new Promise((res) => chrome.storage.local.set({ hive_pending_session: msg.payload as SessionRequest }, () => res(null)));
      chrome.action.openPopup();
      try {
        chrome.runtime.sendMessage({ type: "SHOW_SESSION_REQUEST", payload: msg.payload as SessionRequest }, () => {
          // Swallow error if no listener yet (popup not open)
          // eslint-disable-next-line @typescript-eslint/no-unused-expressions
          chrome.runtime.lastError;
        });
      } catch {}
      sendResponse({ ok: true });
    })();
    return true;
  }

  if (msg?.type === "HIVE_UPDATE_CONTEXT") {
    (async () => {
      const { sessionToken, events, origin } = msg.payload || {};
      try {
        if (!isAllowedOrigin(origin)) return sendResponse({ ok: false, error: "origin_not_allowed" });
        const user = await getStoredUser();
        if (!user) return sendResponse({ ok: false, error: "no_user" });
        if (!sessionToken || sessionToken.sub !== user.userId) return sendResponse({ ok: false, error: "invalid_token_sub" });
        if (sessionToken.exp < Math.floor(Date.now() / 1000)) return sendResponse({ ok: false, error: "token_expired" });
        if (sessionToken.origin && origin && sessionToken.origin !== origin) return sendResponse({ ok: false, error: "origin_mismatch" });
        if (await isSessionRevoked(sessionToken.sessionId)) return sendResponse({ ok: false, error: "session_revoked" });

        const arrIn: any[] = Array.isArray(events) ? events : [];
        const now = Date.now();
        const safe = arrIn.map((e) => ({
          type: typeof e?.type === 'string' ? e.type : 'event',
          data: e?.data ?? e?.content ?? null,
          ts: typeof e?.ts === 'number' ? e.ts : now
        }));
        const key = `hive_ctx_${(sessionToken.origin || origin || '').replace(/[^a-z0-9_:\/.-]/gi,'_')}_${sessionToken.sessionId}`;
        chrome.storage.local.get([key], (items: Record<string, any>) => {
          const cur: any[] = Array.isArray(items[key]) ? items[key] : [];
          const merged = cur.concat(safe);
          const trimmed = merged.slice(-100);
          chrome.storage.local.set({ [key]: trimmed, hive_last_context_size: trimmed.length }, () => {
            sendResponse({ ok: true, size: trimmed.length });
          });
        });
      } catch (e) {
        return sendResponse({ ok: false, error: String(e) });
      }
    })();
    return true;
  }

  if (msg?.type === "HIVE_POPUP_CHAT") {
    (async () => {
      const { messages, model } = msg.payload || {};
      try {
        const reg = await getRegistry();
        const active = reg.active;
        const key = (await getProviderToken(active)) || reg.tokens?.[active];
        if (!active) return sendResponse({ ok: false, error: "no_active_provider" });
        if (!key && active !== 'local') return sendResponse({ ok: false, error: "no_provider_key" });
        const sysPersona = await getPersonaProfile();
        const lang = (typeof navigator !== 'undefined' && (navigator as any)?.language) || (chrome && chrome.i18n && chrome.i18n.getUILanguage && chrome.i18n.getUILanguage()) || 'en';
        const kws = (sysPersona.keywords || "").split(",").map((s)=>s.trim()).filter(Boolean).slice(0,5).join(", ");
        const sys = `You are ${sysPersona.name || 'Hive'}, tone formality ${sysPersona?.tone?.formality ?? 50}/100, concision ${sysPersona?.tone?.concision ?? 50}/100${kws?`, keywords: ${kws}`:''}. ${sysPersona.rules ? ('Guidelines: '+sysPersona.rules) : ''} Browser language: ${lang}. Prefer responding in that language unless the user specifies otherwise.`.trim();
        const baseMessages = Array.isArray(messages) ? messages : [];
        const finalMessages = [{ role:'system', content: sys }, ...baseMessages];

        if (active === 'openai' && key) {
          const { resp, json } = await fetchJsonWithTimeout('https://api.openai.com/v1/chat/completions', {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${key}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ model: model || reg.prefModels?.openai || 'gpt-4o-mini', messages: finalMessages, temperature: 0.7 })
          }, 15000);
          const text = json?.choices?.[0]?.message?.content || '';
          return sendResponse({ ok: resp.ok, text, raw: json });
        }

        if (active === 'deepseek' && key) {
          // Support DeepSeek via API key (official) or custom base URL (if token is a URL)
          const isUrl = /^https?:\/\//i.test(String(key));
          const base = isUrl ? String(key).trim().replace(/\/+$/, '') : 'https://api.deepseek.com';
          const u = `${base}/v1/chat/completions`;
          const headers: Record<string,string> = { 'Content-Type': 'application/json' };
          if (!isUrl) headers['Authorization'] = `Bearer ${key}`;
          const { resp, json } = await fetchJsonWithTimeout(u, { method: 'POST', headers, body: JSON.stringify({ model: model || reg.prefModels?.deepseek || 'deepseek-chat', messages: finalMessages, temperature: 0.7 }) }, 15000);
          const text = json?.choices?.[0]?.message?.content || '';
          return sendResponse({ ok: resp.ok, text, raw: json });
        }

        if (active === 'grok' && key) {
          // Require a base URL for Grok for now (OpenAI-compatible servers). If not a URL, ask for base URL.
          const isUrl = /^https?:\/\//i.test(String(key));
          if (!isUrl) return sendResponse({ ok: false, error: 'grok_requires_base_url_token' });
          const base = String(key).trim().replace(/\/+$/, '');
          const u = `${base}/v1/chat/completions`;
          const { resp, json } = await fetchJsonWithTimeout(u, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ model: model || reg.prefModels?.grok || 'grok', messages: finalMessages, temperature: 0.7 }) }, 15000);
          const text = json?.choices?.[0]?.message?.content || '';
          return sendResponse({ ok: resp.ok, text, raw: json });
        }

        if (active === 'claude' && key) {
          const mapped = mapOpenAIToClaudeBody({ model: model || reg.prefModels?.claude, messages: finalMessages });
          const { resp, json } = await fetchJsonWithTimeout('https://api.anthropic.com/v1/messages', {
            method: 'POST', headers: { 'Content-Type': 'application/json', 'x-api-key': key as string, 'anthropic-version': '2023-06-01' },
            body: JSON.stringify(mapped)
          }, 15000);
          const text = Array.isArray(json?.content) && json.content[0]?.text ? json.content[0].text : '';
          return sendResponse({ ok: resp.ok, text, raw: json });
        }

        if (active === 'gemini' && key) {
          const mapped = mapOpenAIToGeminiBody({ model: model || reg.prefModels?.gemini, messages: finalMessages });
          const u = `https://generativelanguage.googleapis.com/v1/models/${encodeURIComponent(mapped.model)}:generateContent?key=${encodeURIComponent(key)}`;
          const { resp, json } = await fetchJsonWithTimeout(u, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ contents: mapped.contents }) }, 15000);
          const parts = json?.candidates?.[0]?.content?.parts || [];
          const text = parts.map((p:any)=>p?.text||'').filter(Boolean).join('\n');
          return sendResponse({ ok: resp.ok, text, raw: json });
        }

        if (active === 'local' && key) {
          const base = String(key).trim().replace(/\/+$/, '');
          const u = `${base}/v1/chat/completions`;
          const { resp, json } = await fetchJsonWithTimeout(u, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ model: 'local', messages: finalMessages, temperature: 0.7 }) }, 12000);
          const text = json?.choices?.[0]?.message?.content || '';
          return sendResponse({ ok: resp.ok, text, raw: json });
        }

        return sendResponse({ ok: false, error: 'unsupported_provider' });
      } catch (e) {
        return sendResponse({ ok: false, error: String(e) });
      }
    })();
    return true;
  }

  if (msg?.type === "HIVE_SUGGEST_REPLY") {
    (async () => {
      const { sessionToken, thread, origin, max_suggestions } = msg.payload || {};
      try {
        if (!isAllowedOrigin(origin)) return sendResponse({ ok: false, error: "origin_not_allowed" });
        const user = await getStoredUser();
        if (!user) return sendResponse({ ok: false, error: "no_user" });
        if (!sessionToken || sessionToken.sub !== user.userId) return sendResponse({ ok: false, error: "invalid_token_sub" });
        if (sessionToken.exp < Math.floor(Date.now() / 1000)) return sendResponse({ ok: false, error: "token_expired" });
        if (sessionToken.origin && origin && sessionToken.origin !== origin) return sendResponse({ ok: false, error: "origin_mismatch" });
        if (await isSessionRevoked(sessionToken.sessionId)) return sendResponse({ ok: false, error: "session_revoked" });

        const reg = await getRegistry();
        const active = reg.active;
        const key = (await getProviderToken(active)) || reg.tokens?.[active];
        if (!key && active !== 'local') return sendResponse({ ok: false, error: "no_provider_key" });
        const sysPersona = await getPersonaProfile();
        const lang = (typeof navigator !== 'undefined' && (navigator as any)?.language) || (chrome && chrome.i18n && chrome.i18n.getUILanguage && chrome.i18n.getUILanguage()) || 'en';
        const kws = (sysPersona.keywords || "").split(",").map((s)=>s.trim()).filter(Boolean).slice(0,5).join(", ");
        const sys = `You are ${sysPersona.name || 'Hive'}, tone formality ${sysPersona?.tone?.formality ?? 50}/100, concision ${sysPersona?.tone?.concision ?? 50}/100${kws?`, keywords: ${kws}`:''}. ${sysPersona.rules ? ('Guidelines: '+sysPersona.rules) : ''} Browser language: ${lang}. Prefer responding in that language unless the user specifies otherwise.`.trim();
        const baseMessages = Array.isArray(thread) ? thread : [];
        const finalMessages = [{ role:'system', content: sys }, ...baseMessages];

        // Helper to parse suggestions
        const nMax = Math.max(1, Math.min(5, Number(max_suggestions || 3)));
        const parseSuggestions = (text: string): string[] => {
          if (!text) return [];
          let parts: string[] = [];
          if (text.includes('\n---\n')) parts = text.split(/\n---\n/g);
          else if (/^\s*[-*]/m.test(text)) parts = text.split(/\n\s*[-*]\s+/g).map((s)=>s.trim()).filter(Boolean);
          else parts = text.split(/\n\n+/g);
          return parts.map((s)=>s.trim()).filter(Boolean).slice(0, nMax);
        };

        if (active === 'openai' && key) {
          const { resp, json } = await fetchJsonWithTimeout('https://api.openai.com/v1/chat/completions', {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${key}`, 'Content-Type': 'application/json' },
            body: JSON.stringify({ model: reg.prefModels?.openai || 'gpt-4o-mini', messages: finalMessages, temperature: 0.5, max_tokens: 128 })
          }, 8000);
          const text = json?.choices?.[0]?.message?.content || '';
          return sendResponse({ ok: resp.ok, suggestions: parseSuggestions(text), raw: json, status: resp.status });
        }

        if (active === 'deepseek' && key) {
          try {
            const isUrl = /^https?:\/\//i.test(String(key));
            const base = isUrl ? String(key).trim().replace(/\/+$/, '') : 'https://api.deepseek.com';
            const u = `${base}/v1/chat/completions`;
            const headers: Record<string,string> = { 'Content-Type': 'application/json' };
            if (!isUrl) headers['Authorization'] = `Bearer ${key}`;
            const { resp, json } = await fetchJsonWithTimeout(u, { method: 'POST', headers, body: JSON.stringify({ model: reg.prefModels?.deepseek || 'deepseek-chat', messages: finalMessages, temperature: 0.5, max_tokens: 128 }) }, 12000);
            const text = json?.choices?.[0]?.message?.content || '';
            return sendResponse({ ok: resp.ok, suggestions: parseSuggestions(text), raw: json, status: resp.status });
          } catch (e) {
            return sendResponse({ ok: false, error: String(e) });
          }
        }

        if (active === 'grok' && key) {
          try {
            const isUrl = /^https?:\/\//i.test(String(key));
            if (!isUrl) return sendResponse({ ok: false, error: 'grok_requires_base_url_token' });
            const base = String(key).trim().replace(/\/+$/, '');
            const u = `${base}/v1/chat/completions`;
            const { resp, json } = await fetchJsonWithTimeout(u, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ model: reg.prefModels?.grok || 'grok', messages: finalMessages, temperature: 0.5, max_tokens: 128 }) }, 12000);
            const text = json?.choices?.[0]?.message?.content || '';
            return sendResponse({ ok: resp.ok, suggestions: parseSuggestions(text), raw: json, status: resp.status });
          } catch (e) {
            return sendResponse({ ok: false, error: String(e) });
          }
        }

        if (active === 'local' && key) {
          try {
            const base = String(key).trim().replace(/\/+$/, "");
            const u1 = `${base}/v1/chat/completions`;
            const u2 = `${base}/chat/completions`;
            const p1 = fetchJsonWithTimeout(u1, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ model: 'local', messages: finalMessages, temperature: 0.5, max_tokens: 128 }) }, 8000)
              .then(({resp,json})=>({resp,json,url:u1})).catch(()=>null);
            const p2 = fetchJsonWithTimeout(u2, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ model: 'local', messages: finalMessages, temperature: 0.5, max_tokens: 128 }) }, 8000)
              .then(({resp,json})=>({resp,json,url:u2})).catch(()=>null);
            const first = await Promise.race([p1, p2].filter(Boolean) as Promise<any>[]);
            if (first && first.resp.ok) {
              const text = first.json?.choices?.[0]?.message?.content || '';
              return sendResponse({ ok: true, suggestions: parseSuggestions(text), raw: first.json, status: first.resp.status, usedUrl: first.url });
            }
            return sendResponse({ ok: false, error: 'local_timeout_or_error' });
          } catch (e) {
            return sendResponse({ ok: false, error: String(e) });
          }
        }

        return sendResponse({ ok: false, error: "unsupported_provider" });
      } catch (e) {
        return sendResponse({ ok: false, error: String(e) });
      }
    })();
    return true;
  }

  if (msg?.type === "HIVE_CREATE_TOKEN") {
    (async () => {
      const { userId, sessionId, scopes, origin, singleUse } = msg.payload || {};
      if (!userId || !sessionId || !Array.isArray(scopes)) return sendResponse({ ok: false, error: "invalid_args" });
      if (!isAllowedOrigin(origin)) return sendResponse({ ok: false, error: "origin_not_allowed" });
      const token = await createClientSignedToken(userId, sessionId, scopes, origin);
      if (singleUse) (token as ClientSignedToken).singleUse = true;
      await new Promise((res) => chrome.storage.local.set({ hive_last_session_id: token.sessionId }, () => res(null)));
      sendResponse({ ok: true, token });
    })();
    return true;
  }

  if (msg?.type === "HIVE_REVOKE_TOKEN") {
    (async () => {
      const { sessionId } = msg.payload || {};
      if (!sessionId) return sendResponse({ ok: false, error: "invalid_args" });
      await revokeSession(sessionId);
      sendResponse({ ok: true });
    })();
    return true;
  }

  if (msg?.type === "HIVE_LIST_MODELS") {
    (async () => {
      const reg = await getRegistry();
      const active = reg.active;
      const key = (await getProviderToken(active)) || reg.tokens?.[active];
      if (active !== "gemini" || !key) return sendResponse({ ok: false, error: "no_key_or_not_gemini" });
      try {
        const v1 = await fetch(`https://generativelanguage.googleapis.com/v1/models?key=${encodeURIComponent(key)}`).then(r=>r.json());
        const v1beta = await fetch(`https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(key)}`).then(r=>r.json());
        sendResponse({ ok: true, v1, v1beta });
      } catch (e) {
        sendResponse({ ok: false, error: String(e) });
      }
    })();
    return true;
  }

  if (msg?.type === "APP_FORWARD_REQUEST") {
    (async () => {
      const { sessionToken, requestPayload, origin } = msg.payload || {};
      if (!isAllowedOrigin(origin)) return sendResponse({ ok: false, error: "origin_not_allowed" });
      const user = await getStoredUser();
      if (!user) return sendResponse({ ok: false, error: "no_user" });
      if (!sessionToken || sessionToken.sub !== user.userId) return sendResponse({ ok: false, error: "invalid_token_sub" });
      if (sessionToken.exp < Math.floor(Date.now() / 1000)) return sendResponse({ ok: false, error: "token_expired" });
      if (sessionToken.origin && origin && sessionToken.origin !== origin) return sendResponse({ ok: false, error: "origin_mismatch" });
      if (await isSessionRevoked(sessionToken.sessionId)) return sendResponse({ ok: false, error: "session_revoked" });
      if (sessionToken.singleUse && (await isTokenUsed(sessionToken.signature))) return sendResponse({ ok: false, error: "token_reused" });
      // Provider routing via registry (fallback to echo)
      const reg = await getRegistry();
      const active = reg.active;
      const key = (await getProviderToken(active)) || reg.tokens?.[active];

      if (active === "openai" && key && requestPayload) {
        try {
          const resp = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${key}`,
              "Content-Type": "application/json"
            },
            body: JSON.stringify(requestPayload)
          });
          const json = await resp.json();
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: resp.ok, response: json, status: resp.status });
        } catch (e) {
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: false, error: String(e) });
        }
      }

      if (active === 'deepseek' && key && requestPayload) {
        try {
          const isUrl = /^https?:\/\//i.test(String(key));
          const base = isUrl ? String(key).trim().replace(/\/+$/, '') : 'https://api.deepseek.com';
          const u = `${base}/v1/chat/completions`;
          const headers: Record<string,string> = { 'Content-Type': 'application/json' };
          if (!isUrl) headers['Authorization'] = `Bearer ${key}`;
          const resp = await fetch(u, { method: 'POST', headers, body: JSON.stringify(requestPayload) });
          const json = await resp.json();
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: resp.ok, response: json, status: resp.status, usedUrl: u });
        } catch (e) {
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: false, error: String(e) });
        }
      }

      if (active === 'grok' && key && requestPayload) {
        try {
          const isUrl = /^https?:\/\//i.test(String(key));
          if (!isUrl) return sendResponse({ ok: false, error: 'grok_requires_base_url_token' });
          const base = String(key).trim().replace(/\/+$/, '');
          const u = `${base}/v1/chat/completions`;
          const resp = await fetch(u, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(requestPayload) });
          const json = await resp.json();
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: resp.ok, response: json, status: resp.status, usedUrl: u });
        } catch (e) {
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: false, error: String(e) });
        }
      }

      if (active === "local" && key && requestPayload) {
        try {
          const base = String(key).trim().replace(/\/+$/, "");
          const endpoints = [
            `${base}/v1/chat/completions`,
            `${base}/chat/completions`,
            `${base}/v1/messages`,
            `${base}/chat`
          ];
          const tried: Array<{ url: string; status: number; body?: any }> = [];
          let lastJson: any = null;
          for (const u of endpoints) {
            const resp = await fetch(u, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify(requestPayload)
            });
            let json: any = null;
            try { json = await resp.json(); } catch { json = { text: await resp.text() }; }
            tried.push({ url: u, status: resp.status, body: json });
            if (resp.ok) {
              if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
              return sendResponse({ ok: true, response: json, status: resp.status, usedUrl: u, tried });
            }
            lastJson = json;
          }
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: false, response: lastJson, status: 502, tried });
        } catch (e) {
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: false, error: String(e) });
        }
      }

      if (active === "claude" && key && requestPayload) {
        try {
          const mapped = mapOpenAIToClaudeBody(requestPayload);
          const prefClaude = await getPreferredModel("claude");
          if (prefClaude) mapped.model = prefClaude;
          const resp = await fetch("https://api.anthropic.com/v1/messages", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-api-key": key as string,
              "anthropic-version": "2023-06-01"
            },
            body: JSON.stringify(mapped)
          });
          const json = await resp.json();
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: resp.ok, response: json, status: resp.status, usedUrl: "https://api.anthropic.com/v1/messages" });
        } catch (e) {
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: false, error: String(e) });
        }
      }

      if (active === "gemini" && key && requestPayload) {
        try {
          const mapped = mapOpenAIToGeminiBody(requestPayload);
          const pref = await getPreferredModel("gemini");
          const candidateModels = Array.from(new Set([
            pref || "",
            mapped.model,
            mapped.model.replace('-latest',''),
            'gemini-1.5-flash',
            'gemini-1.5-flash-001',
            'gemini-1.5-pro',
            'gemini-1.5-pro-001'
          ])).filter(Boolean);
          const tried: Array<{ url: string; status: number; body?: any }> = [];
          let lastJson: any = null;
          for (const model of candidateModels) {
            const urls = [
              `https://generativelanguage.googleapis.com/v1/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(key)}`,
              `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(key)}`,
            ];
            for (const u of urls) {
              const resp = await fetch(u, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({ contents: mapped.contents })
              });
              const json = await resp.json();
              tried.push({ url: u, status: resp.status, body: json });
              if (resp.ok || resp.status !== 404) {
                try { await setPreferredModel("gemini", model); } catch {}
                if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
                return sendResponse({ ok: resp.ok, response: json, status: resp.status, usedUrl: u, tried });
              }
              lastJson = json;
            }
          }

          // Auto-discover models via ListModels and retry any that support generateContent
          try {
            const lists = [
              `https://generativelanguage.googleapis.com/v1/models?key=${encodeURIComponent(key)}`,
              `https://generativelanguage.googleapis.com/v1beta/models?key=${encodeURIComponent(key)}`,
            ];
            for (const listUrl of lists) {
              const listResp = await fetch(listUrl);
              const listJson = await listResp.json();
              const models: any[] = Array.isArray(listJson?.models) ? listJson.models : [];
              for (const m of models) {
                const name: string = m?.name || "";
                const methods: string[] = m?.supportedGenerationMethods || m?.supported_generation_methods || [];
                if (!name || !methods.some((x) => x.toLowerCase().includes("generatecontent"))) continue;
                const endpoints = [
                  `https://generativelanguage.googleapis.com/v1/models/${encodeURIComponent(name)}:generateContent?key=${encodeURIComponent(key)}`,
                  `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(name)}:generateContent?key=${encodeURIComponent(key)}`,
                ];
                for (const u of endpoints) {
                  const resp = await fetch(u, {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify({ contents: mapped.contents })
                  });
                  const json = await resp.json();
                  tried.push({ url: u, status: resp.status, body: json });
                  if (resp.ok || resp.status !== 404) {
                    try { await setPreferredModel("gemini", name); } catch {}
                    if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
                    return sendResponse({ ok: resp.ok, response: json, status: resp.status, usedUrl: u, tried });
                  }
                  lastJson = json;
                }
              }
            }
          } catch (_) {
            // ignore ListModels fallback errors; we'll return aggregated tried below
          }
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: false, response: lastJson, status: 404, tried });
        } catch (e) {
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: false, error: String(e) });
        }
      }

      // Not implemented providers or missing key → echo
      if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
      sendResponse({ ok: true, response: { echo: true, provider: active, request: requestPayload } });
    })();
    return true;
  }

  sendResponse({ ok: false, error: "unknown_message" });
});
