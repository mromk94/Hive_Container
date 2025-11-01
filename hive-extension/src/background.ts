import type { SessionRequest, ClientSignedToken } from "./types";
import { signStringES256 } from "./crypto";
import { isAllowedOrigin } from "./config";
import { getRegistry, getPreferredModel, setPreferredModel, getProviderToken, getPersonaProfile, setPersonaProfile, setProviderToken, getUserProfile, getUseWebSession } from "./registry";
import { getDefaultGoogleOAuth } from "./config.oauth";
declare const chrome: any;

const EXT_STORAGE_KEY = "hive_extension_user";
const SESSION_TTL_SECONDS = 60 * 30; // 30 minutes
const USED_TOKEN_KEY = "hive_used_tokens"; // store base64url signatures
const REVOKED_SESSIONS_KEY = "hive_revoked_sessions"; // store sessionIds
const BUILD_INFO = "hive-ext build: 2025-10-31 gemini-v1 latest + registry";

async function getStoredUser(): Promise<any | null> {
  return new Promise((res) => chrome.storage.local.get([EXT_STORAGE_KEY], (items: Record<string, any>) => res(items[EXT_STORAGE_KEY] ?? null)));
}

// Build thread history with timestamps
async function buildThreadHistory(take: number = 30): Promise<Array<{ ts:number; role:'user'|'assistant'; content:string }>>{
  try {
    const items: any[] = await new Promise((res)=>{ chrome.storage.local.get(['hive_memory'], (i:any)=> res(Array.isArray(i?.['hive_memory']) ? i['hive_memory'] : [])); });
    const mapped = items
      .filter((e:any)=> typeof e?.text === 'string' || typeof e?.data?.text === 'string')
      .map((e:any)=>{
        const txt = (typeof e?.text === 'string' ? e.text : (typeof e?.data?.text === 'string' ? e.data.text : '')).replace(/\s+/g,' ').trim();
        const role: 'user'|'assistant' = (e?.role === 'assistant' || e?.source === 'gpt') ? 'assistant' : 'user';
        const ts = typeof e?.ts === 'number' ? e.ts : Date.now();
        return { ts, role, content: txt };
      })
      .filter((m)=> m.content)
      .sort((a,b)=> a.ts - b.ts);
    return mapped.slice(-Math.max(2, Math.min(100, take)));
  } catch { return []; }
}

async function sha256Hex(s: string): Promise<string>{
  try {
    // @ts-ignore
    const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
    return Array.from(new Uint8Array(buf)).map(b=>b.toString(16).padStart(2,'0')).join('');
  } catch {
    // Fallback: poor-man hash
    let h = 0; for (let i=0;i<s.length;i++){ h = ((h<<5)-h) + s.charCodeAt(i); h |= 0; }
    return 'x'+(h>>>0).toString(16);
  }
}

async function computeStateHash(): Promise<string>{
  const persona = await getPersonaProfile();
  const hist = await buildThreadHistory(40);
  const base = JSON.stringify({
    persona: { name: persona?.name||'', tone: persona?.tone||{}, keywords: persona?.keywords||'' },
    history: hist.map(m=> ({ r:m.role, c:m.content }))
  });
  return sha256Hex(base);
}

type Vault = { persona:any; lastConversationHash:string; lastMessage:string; threadHistory:Array<{ts:number;role:'user'|'assistant';content:string}>; syncTimestamp:number };
async function getVault(): Promise<Vault|null>{
  return new Promise((res)=> chrome.storage.local.get(['hive_vault'], (i:any)=> res(i?.['hive_vault'] || null)));
}
async function setVault(v: Vault): Promise<void>{
  return new Promise((res)=> chrome.storage.local.set({ hive_vault: v, hive_last_state_hash: v.lastConversationHash }, ()=> res()))
}
async function refreshVault(): Promise<Vault>{
  const persona = await getPersonaProfile();
  const history = await buildThreadHistory(60);
  const lastMessage = history.length ? history[history.length-1].content : '';
  const lastConversationHash = await computeStateHash();
  const v: Vault = { persona, lastConversationHash, lastMessage, threadHistory: history, syncTimestamp: Date.now() };
  await setVault(v);
  return v;
}

// Convert local memory events into chat messages (user/assistant), oldest-first
async function buildMemoryMessages(take: number = 12): Promise<Array<{ role: 'user'|'assistant', content: string }>> {
  try {
    const items: any[] = await new Promise((res)=>{
      chrome.storage.local.get(['hive_memory'], (i:any)=> res(Array.isArray(i?.['hive_memory']) ? i['hive_memory'] : []));
    });
    const mapped = items
      .filter((e:any)=> typeof e?.text === 'string' || typeof e?.data?.text === 'string')
      .map((e:any)=>{
        const txt = (typeof e?.text === 'string' ? e.text : (typeof e?.data?.text === 'string' ? e.data.text : '')).replace(/\s+/g,' ').trim();
        const role: 'user'|'assistant' = (e?.role === 'assistant' || e?.source === 'gpt') ? 'assistant' : 'user';
        const ts = typeof e?.ts === 'number' ? e.ts : 0;
        return { ts, role, content: txt };
      })
      .filter((m)=> m.content)
      .sort((a,b)=> a.ts - b.ts);
    const last = mapped.slice(-Math.max(2, Math.min(40, take)));
    return last.map(({ role, content })=> ({ role, content }));
  } catch { return []; }
}

// Build a concise memory summary from local ring buffer
async function buildMemorySummary(): Promise<string> {
  try {
    const joined: string = await new Promise((res)=>{
      chrome.storage.local.get(['hive_memory'], (i:any)=>{
        const arr: any[] = Array.isArray(i?.['hive_memory']) ? i['hive_memory'] : [];
        const last = arr.slice(-8).reverse();
        const texts = last.map((e:any)=> typeof e?.text === 'string' ? e.text : (typeof e?.data?.text === 'string' ? e.data.text : '')).filter(Boolean);
        const norm = texts.map((t:string)=> t.replace(/\s+/g,' ').trim()).filter(Boolean).slice(0,3).map((s:string)=> s.slice(0,90));
        res(norm.join(' | '));
      });
    });
    return joined;
  } catch {
    return '';
  }
}

function openPopupSafe(){
  try {
    const r = chrome.action.openPopup();
    if (r && typeof r.catch === 'function') r.catch(()=>{});
  } catch {}
}
async function ensureProviderTab(provider: string): Promise<number | null> {
  const existing = await findProviderTabs(provider);
  if (existing.length) return existing[0].id;
  const url = provider === 'openai' ? 'https://chatgpt.com/' :
              provider === 'claude' ? 'https://claude.ai/' :
              provider === 'grok' ? 'https://x.ai/' :
              provider === 'gemini' ? 'https://gemini.google.com/' :
              provider === 'deepseek' ? 'https://deepseek.com/' : '';
  if (!url) return null;
  return new Promise((res)=>{
    try { chrome.tabs.create({ url, active: false }, (t:any)=> res((t && t.id) || null)); } catch { res(null); }
  });
}

// Provider proxy plumbing (page-session fetch)
const proxyWaiters = new Map<string, (payload: any) => void>();
function randomId(){ return Math.random().toString(36).slice(2,10) + Date.now().toString(36); }
async function findProviderTabs(provider: string): Promise<Array<{ id: number, url?: string }>> {
  const patterns: string[] =
    provider === 'openai' ? ['*://chatgpt.com/*','*://*.openai.com/*'] :
    provider === 'claude' ? ['*://claude.ai/*'] :
    provider === 'grok' ? ['*://x.ai/*'] :
    provider === 'gemini' ? ['*://gemini.google.com/*','*://*.google.com/*'] :
    provider === 'deepseek' ? ['*://deepseek.com/*','*://*.deepseek.com/*'] :
    [];
  return new Promise((res)=>{
    if (!patterns.length) return res([]);
    const out: Array<{id:number,url?:string}> = [];
    chrome.tabs.query({}, (tabs:any[])=>{
      for (const t of tabs){
        const u = (t.url || '') as string;
        if (patterns.some(p=>{
          const re = new RegExp('^' + p.replace(/[.*+?^${}()|[\]\\]/g,'\\$&').replace(/\\\*/g,'.*') + '$');
          return re.test(u);
        })) out.push({ id: t.id, url: t.url });
      }
      res(out);
    });
  });
}
function sendViaTab(tabId: number, url: string, init: RequestInit, allowedOrigins: string[]): Promise<any> {
  return new Promise((res)=>{
    const id = randomId();
    proxyWaiters.set(id, (payload:any)=>{ res(payload); });
    chrome.tabs.sendMessage(tabId, { type: 'HIVE_PROVIDER_PROXY', payload: { id, url, init, allowedOrigins } }, ()=>{
      // ignore lastError if no direct response, we wait for RESULT
      // eslint-disable-next-line @typescript-eslint/no-unused-expressions
      chrome.runtime.lastError;
    });
    setTimeout(()=>{
      if (proxyWaiters.has(id)) { proxyWaiters.delete(id); res({ ok:false, error:'proxy_timeout' }); }
    }, 10000);
  });
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

// Heartbeat for sync worker
try { chrome.alarms.create('hive_sync_heartbeat', { periodInMinutes: 1 }); } catch {}
try {
  chrome.alarms.onAlarm.addListener((a:any)=>{ if (a && a.name === 'hive_sync_heartbeat') { try { void refreshVault(); } catch {} } });
} catch {}

chrome.runtime.onMessage.addListener((msg: any, _sender: any, sendResponse: (resp: any) => void) => {
  // Ensure icon set when background activates
  setActionIcons();
  if (msg?.type === 'HIVE_PROVIDER_PROXY_RESULT') {
    const id = msg?.payload?.id;
    if (id && proxyWaiters.has(id)) {
      const fn = proxyWaiters.get(id)!;
      proxyWaiters.delete(id);
      try { fn(msg.payload); } catch {}
    }
    // not a request-response path
  }
  if (msg?.type === 'HIVE_OAUTH_GEMINI_START') {
    (async () => {
      try {
        const cfg = await new Promise<Record<string, any>>((res)=>chrome.storage.local.get(['hive_google_client_id','hive_google_scopes'], (i:any)=>res(i||{})));
        const d = getDefaultGoogleOAuth();
        const clientId = (cfg['hive_google_client_id'] || d.clientId || '').toString();
        const scopes = (cfg['hive_google_scopes'] || d.scopes || 'https://www.googleapis.com/auth/generative-language').toString();
        if (!clientId) return sendResponse({ ok: false, error: 'missing_client_id' });
        const redirect = chrome.identity.getRedirectURL();
        const authUrl = `https://accounts.google.com/o/oauth2/v2/auth?client_id=${encodeURIComponent(clientId)}&response_type=token&redirect_uri=${encodeURIComponent(redirect)}&scope=${encodeURIComponent(scopes)}`;
        chrome.identity.launchWebAuthFlow({ url: authUrl, interactive: true }, async (redirectUrl?: string) => {
          try {
            if (!redirectUrl) return sendResponse({ ok: false, error: (chrome.runtime.lastError && chrome.runtime.lastError.message) || 'no_redirect' });
            const hash = redirectUrl.split('#')[1] || '';
            const params = new URLSearchParams(hash);
            const accessToken = params.get('access_token');
            if (!accessToken) return sendResponse({ ok: false, error: 'no_access_token' });
            await setProviderToken('gemini', `oauth:${accessToken}` as any);
            return sendResponse({ ok: true });
          } catch (e) {
            return sendResponse({ ok: false, error: String(e) });
          }

        if (active === 'claude') {
          try {
            const useWeb = await getUseWebSession('claude');
            const mapped = mapOpenAIToClaudeBody({ model: reg.prefModels?.claude, messages: finalMessages });
            if (useWeb) {
              const tabs = await findProviderTabs('claude');
              if (tabs.length) {
                const r = await sendViaTab(tabs[0].id, 'https://api.anthropic.com/v1/messages', { method:'POST', headers: { 'Content-Type':'application/json', 'anthropic-version': '2023-06-01' }, body: JSON.stringify(mapped) }, []);
                if (r && r.ok) {
                  const text = Array.isArray(r.data?.content) && r.data.content[0]?.text ? r.data.content[0].text : '';
                  return sendResponse({ ok: true, suggestions: parseSuggestions(text), raw: r.data, via: 'web_session' });
                }
                return sendResponse({ ok: false, error: r?.error || 'web_session_failed' });
              }
              return sendResponse({ ok: false, error: 'web_session_not_found' });
            }
            if (key) {
              const { resp, json } = await fetchJsonWithTimeout('https://api.anthropic.com/v1/messages', { method:'POST', headers: { 'Content-Type':'application/json', 'x-api-key': key as string, 'anthropic-version': '2023-06-01' }, body: JSON.stringify(mapped) }, 10000);
              const text = Array.isArray(json?.content) && json.content[0]?.text ? json.content[0].text : '';
              return sendResponse({ ok: resp.ok, suggestions: parseSuggestions(text), raw: json, status: resp.status });
            }
            return sendResponse({ ok: false, error: 'no_provider_key' });
          } catch (e) { return sendResponse({ ok: false, error: String(e) }); }
        }

        if (active === 'gemini') {
          try {
            const mapped = mapOpenAIToGeminiBody({ model: reg.prefModels?.gemini, messages: finalMessages });
            const useWeb = await getUseWebSession('gemini');
            const toText = (data:any)=>{ const parts = data?.candidates?.[0]?.content?.parts || []; return parts.map((p:any)=>p?.text||'').filter(Boolean).join('\n'); };
            if (useWeb) {
              const tabs = await findProviderTabs('gemini');
              if (tabs.length) {
                const u = `https://generativelanguage.googleapis.com/v1/models/${encodeURIComponent(mapped.model)}:generateContent`;
                const r = await sendViaTab(tabs[0].id, u, { method:'POST', headers:{ 'Content-Type':'application/json' }, body: JSON.stringify({ contents: mapped.contents }) }, []);
                if (r && r.ok) {
                  const text = toText(r.data);
                  return sendResponse({ ok: true, suggestions: parseSuggestions(text), raw: r.data, via: 'web_session' });
                }
                return sendResponse({ ok: false, error: r?.error || 'web_session_failed' });
              }
              return sendResponse({ ok: false, error: 'web_session_not_found' });
            }
            if (key) {
              const isOAuth = typeof key === 'string' && key.startsWith('oauth:');
              const token = isOAuth ? key.slice('oauth:'.length) : key;
              const base = `https://generativelanguage.googleapis.com/v1/models/${encodeURIComponent(mapped.model)}:generateContent`;
              const url = isOAuth ? base : `${base}?key=${encodeURIComponent(token)}`;
              const headers: Record<string,string> = { 'Content-Type': 'application/json' };
              if (isOAuth) headers['Authorization'] = `Bearer ${token}`;
              const { resp, json } = await fetchJsonWithTimeout(url, { method:'POST', headers, body: JSON.stringify({ contents: mapped.contents }) }, 12000);
              const text = toText(json);
              return sendResponse({ ok: resp.ok, suggestions: parseSuggestions(text), raw: json, status: resp.status });
            }
            return sendResponse({ ok: false, error: 'no_provider_key' });
          } catch (e) { return sendResponse({ ok: false, error: String(e) }); }
        }
        });
      } catch (e) {
        return sendResponse({ ok: false, error: String(e) });
      }
    })();
    return true;
  }

  // Lightweight cross-surface memory store (local-only)
  if (msg?.type === 'HIVE_RECORD_MEMORY') {
    (async ()=>{
      try {
        const ev = msg?.payload?.event;
        if (!ev || typeof ev !== 'object') return sendResponse({ ok:false, error:'bad_event' });
        const host = (msg?.payload?.origin || '').toString();
        const key = 'hive_memory';
        const now = Date.now();
        const item = { ts: now, origin: host, ...ev };
        const arr = await new Promise<any[]>((res)=> chrome.storage.local.get([key], (i:any)=> res(Array.isArray(i?.[key]) ? i[key] : [])));
        const merged = arr.concat([item]).slice(-500);
        await new Promise((res)=> chrome.storage.local.set({ [key]: merged }, ()=> res(null)));
        try { await refreshVault(); } catch {}
        // Optional auto-tune persona keywords using simple heuristic
        try {
          const autoObj = await new Promise<any>((res)=> chrome.storage.local.get(['hive_auto_tune_persona'], (i:any)=> res(i||{})));
          const auto = !!autoObj['hive_auto_tune_persona'];
          if (auto && typeof ev?.text === 'string') {
            const text = (ev.text as string).toLowerCase();
            const stop = new Set(['about','there','which','these','those','where','should','would','could','thing','think','going','again','after','before','without','within','between','being','while','doing','using','first','second','third','however','therefore','please','thank','thanks','hello','write','reply']);
            const tokens = text.split(/[^a-z0-9]+/g).filter((w: string)=> w && w.length>4 && !stop.has(w));
            if (tokens.length){
              const persona = await getPersonaProfile();
              const cur = (persona.keywords || '').split(',').map((s:string)=>s.trim()).filter(Boolean);
              const add = Array.from(new Set(tokens.slice(0,10).concat(cur))).slice(0,12);
              if (add.join(', ') !== cur.join(', ')){
                const updated = { ...persona, keywords: add.join(', ') } as any;
                await setPersonaProfile(updated);
              }
            }
          }
        } catch {}
        sendResponse({ ok:true, size: merged.length });
      } catch (e) { sendResponse({ ok:false, error:String(e) }); }
    })();
    return true;
  }

  if (msg?.type === 'HIVE_PULL_MEMORY') {
    try {
      const key = 'hive_memory';
      chrome.storage.local.get([key], async (i:any)=>{
        const items: any[] = Array.isArray(i?.[key]) ? i[key] : [];
        const persona = await getPersonaProfile();
        const user = await getUserProfile();
        const messages = await buildMemoryMessages(30);
        const vault = await refreshVault();
        sendResponse({ ok:true, events: items.slice(-200), messages, persona, user, vault });
      });
    } catch (e) { sendResponse({ ok:false, error:String(e) }); }
    return true;
  }

  if (msg?.type === 'HIVE_SYNC') {
    (async ()=>{
      try {
        const clientHash = (msg?.payload?.lastHash || msg?.payload?.clientHash || '').toString();
        const vault = await refreshVault();
        const changed = !clientHash || clientHash !== vault.lastConversationHash;
        sendResponse({ ok:true, changed, vault, lastHash: vault.lastConversationHash, ts: vault.syncTimestamp });
      } catch (e) { sendResponse({ ok:false, error:String(e) }); }
    })();
    return true;
  }
  if (msg?.type === "HIVE_SESSION_REQUEST") {
    // openPopup must run in direct response to user gesture; avoid awaits first
    openPopupSafe();
    // Store pending request and meta (async)
    try {
      const meta = { tabId: _sender?.tab?.id ?? null, frameId: _sender?.frameId ?? null, ts: Date.now() };
      chrome.storage.local.set({ hive_pending_session: msg.payload as SessionRequest, hive_pending_session_tab: meta }, ()=>{});
    } catch {}
    // Nudge popup to render
    try {
      chrome.runtime.sendMessage({ type: "SHOW_SESSION_REQUEST", payload: msg.payload as SessionRequest }, () => {
        // Swallow error if no listener yet (popup not open)
        // eslint-disable-next-line @typescript-eslint/no-unused-expressions
        chrome.runtime.lastError;
      });
    } catch {}
    sendResponse({ ok: true });
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
        const sysPersona = await getPersonaProfile();
        const memSummary = await buildMemorySummary();
        const memThread = await buildMemoryMessages(12);
        const usr = await getUserProfile();
        const lang = (typeof navigator !== 'undefined' && (navigator as any)?.language) || (chrome && chrome.i18n && chrome.i18n.getUILanguage && chrome.i18n.getUILanguage()) || 'en';
        const kws = (sysPersona.keywords || "").split(",").map((s)=>s.trim()).filter(Boolean).slice(0,5).join(", ");
        const up = [
          usr.personality && `Personality: ${usr.personality}`,
          usr.allergies && `Allergies: ${usr.allergies}`,
          usr.preferences && `Preferences: ${usr.preferences}`,
          usr.location && `Location: ${usr.location}`,
          usr.interests && `Interests: ${usr.interests}`,
          usr.education && `Education: ${usr.education}`,
          usr.socials && `Socials: ${usr.socials}`
        ].filter(Boolean).join(' | ');
        const sys = `You are ${sysPersona.name || 'Hive'}, tone formality ${sysPersona?.tone?.formality ?? 50}/100, concision ${sysPersona?.tone?.concision ?? 50}/100${kws?`, keywords: ${kws}`:''}. ${sysPersona.rules ? ('Guidelines: '+sysPersona.rules) : ''}${up?` User Profile: ${up}.`:''}${memSummary?` Recent memory: ${memSummary}.`:''} Browser language: ${lang}. Prefer responding in that language unless the user specifies otherwise.`.trim();
        const baseMessages = Array.isArray(messages) ? messages : [];
        const finalMessages = [{ role:'system', content: sys }, ...memThread, ...baseMessages];

        if (active === 'openai') {
          const useWeb = await getUseWebSession('openai');
          const mappedBody = { model: model || reg.prefModels?.openai || 'gpt-4o-mini', messages: finalMessages, temperature: 0.7 };
          if (useWeb) {
            const tabs = await findProviderTabs('openai');
            if (tabs.length) {
              const u = 'https://api.openai.com/v1/chat/completions';
              const r = await sendViaTab(tabs[0].id, u, { method:'POST', headers: { 'Content-Type':'application/json' }, body: JSON.stringify(mappedBody) }, []);
              if (r && r.ok) {
                const text = r.data?.choices?.[0]?.message?.content || '';
                return sendResponse({ ok: true, text, raw: r.data, via: 'web_session' });
              }
              return sendResponse({ ok: false, error: r?.error || 'web_session_failed' });
            }
            return sendResponse({ ok: false, error: 'web_session_not_found' });
          }
          if (key) {
          const { resp, json } = await fetchJsonWithTimeout('https://api.openai.com/v1/chat/completions', {
            method: 'POST',
            headers: { 'Authorization': `Bearer ${key}`, 'Content-Type': 'application/json' },
            body: JSON.stringify(mappedBody)
          }, 15000);
          const text = json?.choices?.[0]?.message?.content || '';
          return sendResponse({ ok: resp.ok, text, raw: json });
          }
          return sendResponse({ ok: false, error: 'no_provider_key' });
        }

        if (active === 'deepseek') {
          const useWeb = await getUseWebSession('deepseek');
          const mappedBody = { model: model || reg.prefModels?.deepseek || 'deepseek-chat', messages: finalMessages, temperature: 0.7 };
          if (useWeb) {
            const tabs = await findProviderTabs('deepseek');
            if (tabs.length) {
              const u = 'https://api.deepseek.com/v1/chat/completions';
              const r = await sendViaTab(tabs[0].id, u, { method:'POST', headers: { 'Content-Type':'application/json' }, body: JSON.stringify(mappedBody) }, []);
              if (r && r.ok) {
                const text = r.data?.choices?.[0]?.message?.content || '';
                return sendResponse({ ok: true, text, raw: r.data, via: 'web_session' });
              }
              return sendResponse({ ok: false, error: r?.error || 'web_session_failed' });
            }
            return sendResponse({ ok: false, error: 'web_session_not_found' });
          }
          if (key) {
            const isUrl = /^https?:\/\//i.test(String(key));
            const base = isUrl ? String(key).trim().replace(/\/+$/, '') : 'https://api.deepseek.com';
            const u = `${base}/v1/chat/completions`;
            const headers: Record<string,string> = { 'Content-Type': 'application/json' };
            if (!isUrl) headers['Authorization'] = `Bearer ${key}`;
            const { resp, json } = await fetchJsonWithTimeout(u, { method: 'POST', headers, body: JSON.stringify(mappedBody) }, 15000);
            const text = json?.choices?.[0]?.message?.content || '';
            return sendResponse({ ok: resp.ok, text, raw: json });
          }
          return sendResponse({ ok: false, error: 'no_provider_key' });
        }

        if (active === 'grok') {
          const useWeb = await getUseWebSession('grok');
          const mappedBody = { model: model || reg.prefModels?.grok || 'grok', messages: finalMessages, temperature: 0.7 };
          if (useWeb) {
            const tabs = await findProviderTabs('grok');
            if (tabs.length) {
              const u = 'https://api.x.ai/v1/chat/completions';
              const r = await sendViaTab(tabs[0].id, u, { method:'POST', headers: { 'Content-Type':'application/json' }, body: JSON.stringify(mappedBody) }, []);
              if (r && r.ok) {
                const text = r.data?.choices?.[0]?.message?.content || '';
                return sendResponse({ ok: true, text, raw: r.data, via: 'web_session' });
              }
              return sendResponse({ ok: false, error: r?.error || 'web_session_failed' });
            }
            return sendResponse({ ok: false, error: 'web_session_not_found' });
          }
          if (key) {
            const isUrl = /^https?:\/\//i.test(String(key));
            if (!isUrl) return sendResponse({ ok: false, error: 'grok_requires_base_url_token' });
            const base = String(key).trim().replace(/\/+$/, '');
            const u = `${base}/v1/chat/completions`;
            const { resp, json } = await fetchJsonWithTimeout(u, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(mappedBody) }, 15000);
            const text = json?.choices?.[0]?.message?.content || '';
            return sendResponse({ ok: resp.ok, text, raw: json });
          }
          return sendResponse({ ok: false, error: 'no_provider_key' });
        }

        if (active === 'claude') {
          const useWeb = await getUseWebSession('claude');
          const mapped = mapOpenAIToClaudeBody({ model: model || reg.prefModels?.claude, messages: finalMessages });
          if (useWeb) {
            const tabs = await findProviderTabs('claude');
            if (tabs.length) {
              const u = 'https://api.anthropic.com/v1/messages';
              const r = await sendViaTab(tabs[0].id, u, { method:'POST', headers: { 'Content-Type':'application/json', 'anthropic-version': '2023-06-01' }, body: JSON.stringify(mapped) }, []);
              if (r && r.ok) {
                const text = Array.isArray(r.data?.content) && r.data.content[0]?.text ? r.data.content[0].text : '';
                return sendResponse({ ok: true, text, raw: r.data, via: 'web_session' });
              }
              return sendResponse({ ok: false, error: r?.error || 'web_session_failed' });
            }
            return sendResponse({ ok: false, error: 'web_session_not_found' });
          }
          if (key) {
            const { resp, json } = await fetchJsonWithTimeout('https://api.anthropic.com/v1/messages', {
              method: 'POST', headers: { 'Content-Type': 'application/json', 'x-api-key': key as string, 'anthropic-version': '2023-06-01' },
              body: JSON.stringify(mapped)
            }, 15000);
            const text = Array.isArray(json?.content) && json.content[0]?.text ? json.content[0].text : '';
            return sendResponse({ ok: resp.ok, text, raw: json });
          }
          return sendResponse({ ok: false, error: 'no_provider_key' });
        }

        if (active === 'gemini') {
          const mapped = mapOpenAIToGeminiBody({ model: model || reg.prefModels?.gemini, messages: finalMessages });
          const useWeb = await getUseWebSession('gemini');
          if (useWeb) {
            const tabs = await findProviderTabs('gemini');
            if (tabs.length) {
              const u = `https://generativelanguage.googleapis.com/v1/models/${encodeURIComponent(mapped.model)}:generateContent`;
              const r = await sendViaTab(tabs[0].id, u, { method:'POST', headers: { 'Content-Type':'application/json' }, body: JSON.stringify({ contents: mapped.contents }) }, []);
              if (r && r.ok) {
                const parts = r.data?.candidates?.[0]?.content?.parts || [];
                const text = parts.map((p:any)=>p?.text||'').filter(Boolean).join('\n');
                return sendResponse({ ok: true, text, raw: r.data, via: 'web_session' });
              }
              return sendResponse({ ok: false, error: r?.error || 'web_session_failed' });
            }
            return sendResponse({ ok: false, error: 'web_session_not_found' });
          }
          const key = (await getProviderToken('gemini')) || reg.tokens?.['gemini'];
          if (key) {
            const isOAuth = typeof key === 'string' && key.startsWith('oauth:');
            const token = isOAuth ? key.slice('oauth:'.length) : key;
            const base = `https://generativelanguage.googleapis.com/v1/models/${encodeURIComponent(mapped.model)}:generateContent`;
            const url = isOAuth ? base : `${base}?key=${encodeURIComponent(token)}`;
            const headers: Record<string,string> = { 'Content-Type': 'application/json' };
            if (isOAuth) headers['Authorization'] = `Bearer ${token}`;
            const { resp, json } = await fetchJsonWithTimeout(url, { method: 'POST', headers, body: JSON.stringify({ contents: mapped.contents }) }, 15000);
            const parts = json?.candidates?.[0]?.content?.parts || [];
            const text = parts.map((p:any)=>p?.text||'').filter(Boolean).join('\n');
            return sendResponse({ ok: resp.ok, text, raw: json });
          }
          return sendResponse({ ok: false, error: 'no_provider_key' });
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
        // Do not require a key if Web Session is enabled; provider branches handle fallbacks
        const sysPersona = await getPersonaProfile();
        const memSummary = await buildMemorySummary();
        const memThread = await buildMemoryMessages(8);
        const usr = await getUserProfile();
        const lang = (typeof navigator !== 'undefined' && (navigator as any)?.language) || (chrome && chrome.i18n && chrome.i18n.getUILanguage && chrome.i18n.getUILanguage()) || 'en';
        const kws = (sysPersona.keywords || "").split(",").map((s)=>s.trim()).filter(Boolean).slice(0,5).join(", ");
        const up = [
          usr.personality && `Personality: ${usr.personality}`,
          usr.allergies && `Allergies: ${usr.allergies}`,
          usr.preferences && `Preferences: ${usr.preferences}`,
          usr.location && `Location: ${usr.location}`,
          usr.interests && `Interests: ${usr.interests}`
        ].filter(Boolean).join(' | ');
        const sys = `You are ${sysPersona.name || 'Hive'}, tone formality ${sysPersona?.tone?.formality ?? 50}/100, concision ${sysPersona?.tone?.concision ?? 50}/100${kws?`, keywords: ${kws}`:''}. ${sysPersona.rules ? ('Guidelines: '+sysPersona.rules) : ''}${up?` User Profile: ${up}.`:''}${memSummary?` Recent memory: ${memSummary}.`:''} Browser language: ${lang}. Prefer responding in that language unless the user specifies otherwise.`.trim();
        const baseMessages = Array.isArray(thread) ? thread : [];
        const finalMessages = [{ role:'system', content: sys }, ...memThread, ...baseMessages];

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

        if (active === 'openai') {
          const useWeb = await getUseWebSession('openai');
          const body = { model: reg.prefModels?.openai || 'gpt-4o-mini', messages: finalMessages, temperature: 0.5, max_tokens: 128 };
          if (useWeb) {
            const tabs = await findProviderTabs('openai');
            if (tabs.length) {
              const r = await sendViaTab(tabs[0].id, 'https://api.openai.com/v1/chat/completions', { method:'POST', headers: { 'Content-Type':'application/json' }, body: JSON.stringify(body) }, []);
              if (r && r.ok) {
                const text = r.data?.choices?.[0]?.message?.content || '';
                return sendResponse({ ok: true, suggestions: parseSuggestions(text), raw: r.data, via: 'web_session' });
              }
              return sendResponse({ ok: false, error: r?.error || 'web_session_failed' });
            }
            return sendResponse({ ok: false, error: 'web_session_not_found' });
          }
          if (key) {
            const { resp, json } = await fetchJsonWithTimeout('https://api.openai.com/v1/chat/completions', {
              method: 'POST', headers: { 'Authorization': `Bearer ${key}`, 'Content-Type': 'application/json' }, body: JSON.stringify(body)
            }, 8000);
            const text = json?.choices?.[0]?.message?.content || '';
            return sendResponse({ ok: resp.ok, suggestions: parseSuggestions(text), raw: json, status: resp.status });
          }
          return sendResponse({ ok: false, error: 'no_provider_key' });
        }

        if (active === 'deepseek') {
          try {
            const useWeb = await getUseWebSession('deepseek');
            const body = { model: reg.prefModels?.deepseek || 'deepseek-chat', messages: finalMessages, temperature: 0.5, max_tokens: 128 };
            if (useWeb) {
              const tabs = await findProviderTabs('deepseek');
              if (tabs.length) {
                const r = await sendViaTab(tabs[0].id, 'https://api.deepseek.com/v1/chat/completions', { method:'POST', headers: { 'Content-Type':'application/json' }, body: JSON.stringify(body) }, []);
                if (r && r.ok) {
                  const text = r.data?.choices?.[0]?.message?.content || '';
                  return sendResponse({ ok: true, suggestions: parseSuggestions(text), raw: r.data, via: 'web_session' });
                }
                return sendResponse({ ok: false, error: r?.error || 'web_session_failed' });
              }
              return sendResponse({ ok: false, error: 'web_session_not_found' });
            }
            if (key) {
              const isUrl = /^https?:\/\//i.test(String(key));
              const base = isUrl ? String(key).trim().replace(/\/\/+$/, '') : 'https://api.deepseek.com';
              const u = `${base}/v1/chat/completions`;
              const headers: Record<string,string> = { 'Content-Type': 'application/json' };
              if (!isUrl) headers['Authorization'] = `Bearer ${key}`;
              const { resp, json } = await fetchJsonWithTimeout(u, { method: 'POST', headers, body: JSON.stringify(body) }, 12000);
              const text = json?.choices?.[0]?.message?.content || '';
              return sendResponse({ ok: resp.ok, suggestions: parseSuggestions(text), raw: json, status: resp.status });
            }
            return sendResponse({ ok: false, error: 'no_provider_key' });
          } catch (e) {
            return sendResponse({ ok: false, error: String(e) });
          }
        }

        if (active === 'grok') {
          try {
            const useWeb = await getUseWebSession('grok');
            const body = { model: reg.prefModels?.grok || 'grok', messages: finalMessages, temperature: 0.5, max_tokens: 128 };
            if (useWeb) {
              const tabs = await findProviderTabs('grok');
              if (tabs.length) {
                const r = await sendViaTab(tabs[0].id, 'https://api.x.ai/v1/chat/completions', { method:'POST', headers: { 'Content-Type':'application/json' }, body: JSON.stringify(body) }, []);
                if (r && r.ok) {
                  const text = r.data?.choices?.[0]?.message?.content || '';
                  return sendResponse({ ok: true, suggestions: parseSuggestions(text), raw: r.data, via: 'web_session' });
                }
                return sendResponse({ ok: false, error: r?.error || 'web_session_failed' });
              }
              return sendResponse({ ok: false, error: 'web_session_not_found' });
            }
            if (key) {
              const isUrl = /^https?:\/\//i.test(String(key));
              if (!isUrl) return sendResponse({ ok: false, error: 'grok_requires_base_url_token' });
              const base = String(key).trim().replace(/\/\/+$/, '');
              const u = `${base}/v1/chat/completions`;
              const { resp, json } = await fetchJsonWithTimeout(u, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) }, 12000);
              const text = json?.choices?.[0]?.message?.content || '';
              return sendResponse({ ok: resp.ok, suggestions: parseSuggestions(text), raw: json, status: resp.status });
            }
            return sendResponse({ ok: false, error: 'no_provider_key' });
          } catch (e) {
            return sendResponse({ ok: false, error: String(e) });
          }
        }

        if (active === 'local' && key) {
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
                body: JSON.stringify({ model: 'local', messages: finalMessages, temperature: 0.5, max_tokens: 128 })
              });
              let json: any = null;
              try { json = await resp.json(); } catch { json = { text: await resp.text() }; }
              tried.push({ url: u, status: resp.status, body: json });
              if (resp.ok) {
                const text = json?.choices?.[0]?.message?.content || '';
                return sendResponse({ ok: true, suggestions: parseSuggestions(text), raw: json, status: resp.status, usedUrl: u, tried });
              }
              lastJson = json;
            }
            return sendResponse({ ok: false, error: 'local_timeout_or_error', tried, last: lastJson });
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
      try { await new Promise((res)=>chrome.storage.local.remove(['hive_last_session_id'], ()=>res(null))); } catch {}
      try {
        chrome.tabs.query({}, (tabs:any[])=>{
          for (const t of tabs) {
            try { chrome.tabs.sendMessage(t.id, { type: 'HIVE_SESSION_REVOKED', payload: { sessionId } }); } catch {}
          }
        });
      } catch {}
      sendResponse({ ok: true, revoked: sessionId });
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
        const isOAuth = typeof key === 'string' && key.startsWith('oauth:');
        const token = isOAuth ? key.slice('oauth:'.length) : key;
        const h: Record<string,string> = isOAuth ? { 'Authorization': `Bearer ${token}` } : {};
        const v1 = await fetch(`https://generativelanguage.googleapis.com/v1/models${isOAuth?'':`?key=${encodeURIComponent(token)}`}`, { headers: h }).then(r=>r.json());
        const v1beta = await fetch(`https://generativelanguage.googleapis.com/v1beta/models${isOAuth?'':`?key=${encodeURIComponent(token)}`}`, { headers: h }).then(r=>r.json());
        sendResponse({ ok: true, v1, v1beta });
      } catch (e) {
        sendResponse({ ok: false, error: String(e) });
      }
    })();
    return true;
  }

  if (msg?.type === "HIVE_CHECK_CONN") {
    (async () => {
      try {
        const reg = await getRegistry();
        const active = reg.active;
        const key = (await getProviderToken(active)) || reg.tokens?.[active];
        const hasKey = !!key;
        const webEnabled = await getUseWebSession(active);
        let webTabs = 0;
        try { const tabs = await findProviderTabs(active); webTabs = Array.isArray(tabs) ? tabs.length : 0; } catch {}
        sendResponse({ ok: true, active, hasKey, webEnabled, webTabs });
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
            const isOAuth = typeof key === 'string' && key.startsWith('oauth:');
            const token = isOAuth ? key.slice('oauth:'.length) : key;
            const urls = [
              `https://generativelanguage.googleapis.com/v1/models/${encodeURIComponent(model)}:generateContent${isOAuth?'':`?key=${encodeURIComponent(token)}`}`,
              `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent${isOAuth?'':`?key=${encodeURIComponent(token)}`}`,
            ];
            for (const u of urls) {
              const headers: Record<string,string> = { "Content-Type": "application/json" };
              if (isOAuth) headers['Authorization'] = `Bearer ${token}`;
              const resp = await fetch(u, {
                method: "POST",
                headers,
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
            const isOAuth = typeof key === 'string' && key.startsWith('oauth:');
            const token = isOAuth ? key.slice('oauth:'.length) : key;
            const lists = [
              `https://generativelanguage.googleapis.com/v1/models${isOAuth?'':`?key=${encodeURIComponent(token)}`}`,
              `https://generativelanguage.googleapis.com/v1beta/models${isOAuth?'':`?key=${encodeURIComponent(token)}`}`,
            ];
            for (const listUrl of lists) {
              const headers: Record<string,string> = isOAuth ? { 'Authorization': `Bearer ${token}` } : {};
              const listResp = await fetch(listUrl, { headers });
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
                  const headers2: Record<string,string> = { "Content-Type": "application/json" };
                  if (isOAuth) headers2['Authorization'] = `Bearer ${token}`;
                  const resp = await fetch(u, {
                    method: "POST",
                    headers: headers2,
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
