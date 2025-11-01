import type { SessionRequest, ClientSignedToken } from "./types";
import type { ProviderId } from "./registry";
import { getRegistry, setActiveProvider, setProviderToken, setPreferredModel, getProviderToken, getPersonaProfile, setPersonaProfile, getUserProfile, setUserProfile, getUseWebSession, setUseWebSession, getConsentLogs, addConsent, removeConsent } from "./registry";
import { getPublicKeyJwk, signStringES256 } from './crypto';
import { getDefaultGoogleOAuth } from './config.oauth';

declare const chrome: any;

const sessionList = document.getElementById("session-list")!;
const userInfo = document.getElementById("user-info")!;
const setSample = document.getElementById("set-sample-user")!;
// Tabs & Chat UI
const tabChatBtn = document.getElementById("tabbtn-chat") as HTMLButtonElement | null;
const tabConfigBtn = document.getElementById("tabbtn-config") as HTMLButtonElement | null;
const tabProfileBtn = document.getElementById("tabbtn-profile") as HTMLButtonElement | null;
const tabChat = document.getElementById("tab-chat") as HTMLDivElement | null;
const tabConfig = document.getElementById("tab-config") as HTMLDivElement | null;
const tabProfile = document.getElementById("tab-profile") as HTMLDivElement | null;
const chatLog = document.getElementById("chat-log") as HTMLDivElement | null;
const chatInput = document.getElementById("chat-input") as HTMLInputElement | null;
const chatSend = document.getElementById("action-primary") as HTMLButtonElement | null;
const chatApproval = document.getElementById("chat-approval") as HTMLDivElement | null;
const ctxSizeEl = document.getElementById('ctx-size') as HTMLSpanElement | null;
const connStatusEl = document.getElementById('conn-status') as HTMLDivElement | null;
const importBtn = document.getElementById('import-thread') as HTMLButtonElement | null;
const refreshBtn = document.getElementById('refresh-memory') as HTMLButtonElement | null;
const btnMin = document.getElementById('btn-min') as HTMLButtonElement | null;
const btnClose = document.getElementById('btn-close') as HTMLButtonElement | null;
const providerSelect = document.getElementById("provider-select") as HTMLSelectElement | null;
const saveTokenBtn = document.getElementById("save-token") as HTMLButtonElement | null;
const clearTokenBtn = document.getElementById("clear-token") as HTMLButtonElement | null;
const revokeLast = document.getElementById("revoke-last") as HTMLButtonElement | null;
const providerTokenInput = document.getElementById("provider-token") as HTMLInputElement | null;
const debugInfoBtn = document.getElementById("debug-info") as HTMLButtonElement | null;
const providerModelInput = document.getElementById("provider-model") as HTMLInputElement | null;
const saveModelBtn = document.getElementById("save-model") as HTMLButtonElement | null;
const listModelsBtn = document.getElementById("list-models") as HTMLButtonElement | null;
const secureStatus = document.getElementById("secure-status") as HTMLDivElement | null;
const useWebSessionEl = document.getElementById('use-web-session') as HTMLInputElement | null;
const autoTuneEl = document.getElementById('auto-tune-persona') as HTMLInputElement | null;
const capturePageEl = document.getElementById('capture-page-chat') as HTMLInputElement | null;
const actionPrimaryBtn = document.getElementById('action-primary') as HTMLButtonElement | null;
const actionModeBtn = document.getElementById('action-mode') as HTMLButtonElement | null;
const actionMenuEl = document.getElementById('action-menu') as HTMLDivElement | null;
const insertBtn = document.getElementById('chat-insert-page') as HTMLButtonElement | null;
const insertSendBtn = document.getElementById('chat-insert-send-page') as HTMLButtonElement | null;
// OAuth buttons
const oauthOpenAI = document.getElementById('oauth-openai') as HTMLButtonElement | null;
const oauthGemini = document.getElementById('oauth-gemini') as HTMLButtonElement | null;
const oauthClaude = document.getElementById('oauth-claude') as HTMLButtonElement | null;
const oauthGrok = document.getElementById('oauth-grok') as HTMLButtonElement | null;
const oauthDeepseek = document.getElementById('oauth-deepseek') as HTMLButtonElement | null;
// Google OAuth inputs (Gemini)
const googleClientIdInput = document.getElementById('google-client-id') as HTMLInputElement | null;
const googleScopesInput = document.getElementById('google-scopes') as HTMLInputElement | null;
const saveGoogleBtn = document.getElementById('save-google-oauth') as HTMLButtonElement | null;
// Consent UI
const consentList = document.getElementById('consent-list') as HTMLDivElement | null;
const refreshConsentsBtn = document.getElementById('refresh-consents') as HTMLButtonElement | null;
const grantCurrentBtn = document.getElementById('grant-current') as HTMLButtonElement | null;
// Persona UI elements
const personaName = document.getElementById("persona-name") as HTMLInputElement | null;
const personaFormality = document.getElementById("persona-formality") as HTMLInputElement | null;
const personaConcision = document.getElementById("persona-concision") as HTMLInputElement | null;
const personaKeywords = document.getElementById("persona-keywords") as HTMLTextAreaElement | null;
const personaBio = document.getElementById("persona-bio") as HTMLTextAreaElement | null;
const personaRules = document.getElementById("persona-rules") as HTMLTextAreaElement | null;
const valFormality = document.getElementById("val-formality") as HTMLSpanElement | null;
const valConcision = document.getElementById("val-concision") as HTMLSpanElement | null;
const savePersonaBtn = document.getElementById("save-persona") as HTMLButtonElement | null;
// Profile inputs
const profilePersonality = document.getElementById('profile-personality') as HTMLTextAreaElement | null;
const profileAllergies = document.getElementById('profile-allergies') as HTMLInputElement | null;
const profilePreferences = document.getElementById('profile-preferences') as HTMLTextAreaElement | null;
const profileLocation = document.getElementById('profile-location') as HTMLInputElement | null;
const profileInterests = document.getElementById('profile-interests') as HTMLInputElement | null;
const profileEducation = document.getElementById('profile-education') as HTMLInputElement | null;
const profileSocials = document.getElementById('profile-socials') as HTMLTextAreaElement | null;
const saveProfileBtn = document.getElementById('save-profile') as HTMLButtonElement | null;
const genSignedPersonaBtn = document.getElementById('gen-signed-persona') as HTMLButtonElement | null;
const copyPublicKeyBtn = document.getElementById('copy-public-key') as HTMLButtonElement | null;

let pendingSession: SessionRequest | null = null;

type ChatMessage = { role: 'user'|'assistant'|'system'; content: string };
const chatMessages: ChatMessage[] = [];

function renderChat() {
  if (!chatLog) return;
  chatLog.innerHTML = "";
  for (const m of chatMessages) {
    const row = document.createElement('div'); row.className = 'msg' + (m.role === 'user' ? ' you' : '');
    const avatar = document.createElement('div'); avatar.className = 'avatar'; avatar.textContent = m.role === 'assistant' ? 'H' : (m.role === 'user' ? 'Y' : 'S');
    const wrap = document.createElement('div');
    const who = document.createElement('div'); who.className = 'who'; who.textContent = m.role === 'assistant' ? 'Hive' : (m.role === 'user' ? 'You' : 'System');
    const bub = document.createElement('div'); bub.className = 'bubble'; bub.textContent = m.content;
    wrap.appendChild(who); wrap.appendChild(bub);
    row.appendChild(avatar); row.appendChild(wrap);
    chatLog.appendChild(row);
  }
  try { if (chatLog) chatLog.scrollTop = chatLog.scrollHeight; } catch {}
}

// Load persisted chat on init
function loadChatLog(){
  try {
    chrome.storage.local.get(['hive_popup_chat_log'], (i:any)=>{
      const arr: ChatMessage[] = Array.isArray(i['hive_popup_chat_log']) ? i['hive_popup_chat_log'] : [];
      if (arr.length) { chatMessages.push(...arr); renderChat(); }
    });

// Refresh memory: pull from background and hydrate full chat thread
refreshBtn?.addEventListener('click', ()=>{
  try {
    chrome.runtime.sendMessage({ type: 'HIVE_PULL_MEMORY' }, (resp:any)=>{
      if (!resp || !resp.ok){ alert('Refresh failed'); return; }
      const msgs: Array<{role:'user'|'assistant', content:string}> = Array.isArray(resp.messages) ? resp.messages : [];
      chatMessages.length = 0;
      chatMessages.push({ role:'system', content: 'Hydrated from Hive' });
      for (const m of msgs) chatMessages.push({ role: m.role, content: m.content });
      renderChat();
      try { chrome.storage.local.set({ hive_popup_chat_log: chatMessages.slice(-100) }); } catch {}
    });
  } catch {}
});
  } catch {}
}

// Minimal sync orchestrator client: compare last hash and hydrate if changed
function attemptSync(){
  try {
    chrome.storage.local.get(['hive_last_state_hash'], (i:any)=>{
      const lastHash = (i && i['hive_last_state_hash']) ? String(i['hive_last_state_hash']) : '';
      chrome.runtime.sendMessage({ type:'HIVE_SYNC', payload: { lastHash } }, (resp:any)=>{
        if (!resp || !resp.ok) return;
        if (resp.changed){
          // Pull and hydrate
          chrome.runtime.sendMessage({ type: 'HIVE_PULL_MEMORY' }, (r:any)=>{
            if (!r || !r.ok) return;
            const msgs: Array<{role:'user'|'assistant', content:string}> = Array.isArray(r.messages) ? r.messages : [];
            chatMessages.length = 0;
            chatMessages.push({ role:'system', content: 'Hydrated from Hive' });
            for (const m of msgs) chatMessages.push({ role: m.role, content: m.content });
            renderChat();
            try { chrome.storage.local.set({ hive_popup_chat_log: chatMessages.slice(-100) }); } catch {}
          });
        }
      });
    });
  } catch {}
}

// Import thread from active provider tab and seed chat
importBtn?.addEventListener('click', ()=>{
  (async()=>{
    try {
      // find provider tabs via background to respect provider selection
      const resp = await new Promise<any>((res)=> chrome.runtime.sendMessage({ type: 'HIVE_CHECK_CONN' }, (r:any)=> res(r)));
      const active = resp?.active || 'openai';
      // query tabs for origin and send scrape request
      const origins: Record<string,string[]> = {
        openai: ['https://chatgpt.com/*','https://*.openai.com/*'],
        claude: ['https://claude.ai/*'],
        gemini: ['https://gemini.google.com/*','https://*.google.com/*'],
        grok: ['https://x.ai/*'],
        deepseek: ['https://deepseek.com/*','https://*.deepseek.com/*']
      };
      const pats = origins[active] || [];
      chrome.tabs.query({ url: pats.length ? pats : undefined }, (tabs:any[])=>{
        if (!tabs || !tabs.length) { alert('No provider tab found. Open a chat tab and try again.'); return; }
        const id = tabs[0].id;
        try { chrome.tabs.sendMessage(id, { type:'HIVE_SCRAPE_THREAD', payload: { take: 12 } }, ()=>{ try { chrome.runtime.lastError; } catch {} }); } catch {}
      });
    } catch {}
  })();
});

chrome.runtime.onMessage.addListener((msg:any)=>{
  if (msg?.type === 'HIVE_SCRAPE_THREAD_RESULT'){
    try {
      const arr: Array<{role:'user'|'assistant', content:string}> = Array.isArray(msg.payload?.messages) ? msg.payload.messages : [];
      if (!arr.length) { alert('No messages found in page.'); return; }
      // Seed chat with a divider then imported messages
      chatMessages.push({ role:'system', content:`Imported thread from ${msg.payload?.origin || 'page'}:` });
      for (const m of arr) chatMessages.push({ role: m.role, content: m.content });
      renderChat();
      try { chrome.storage.local.set({ hive_popup_chat_log: chatMessages.slice(-100) }); } catch {}
      // Record import event to memory bus
      try { chrome.runtime.sendMessage({ type:'HIVE_RECORD_MEMORY', payload: { origin: msg.payload?.origin || 'page', event: { source:'page', type:'import_thread', count: arr.length } } }); } catch {}
    } catch {}
  }
});

// Poll for pending session to make approval banner resilient
let pollTimer: number | null = null;
function startPendingPoll(){
  if (pollTimer != null) return;
  pollTimer = window.setInterval(()=>{
    try {
      if (pendingSession) return;
      chrome.storage.local.get(["hive_pending_session"], (items:any)=>{
        const s = items["hive_pending_session"] as SessionRequest | undefined;
        if (s) {
          pendingSession = s;
          renderSession();
          chrome.storage.local.remove(["hive_pending_session"]);
          renderChatApproval();
        }
      });
    } catch {}
  }, 1000);
}
startPendingPoll();
document.addEventListener('visibilitychange', ()=>{ if (!document.hidden) startPendingPoll(); });

async function initUserProfileUI(){
  try {
    const p = await getUserProfile();
    if (profilePersonality) profilePersonality.value = p.personality || '';
    if (profileAllergies) profileAllergies.value = p.allergies || '';
    if (profilePreferences) profilePreferences.value = p.preferences || '';
    if (profileLocation) profileLocation.value = p.location || '';
    if (profileInterests) profileInterests.value = p.interests || '';
    if (profileEducation) profileEducation.value = p.education || '';
    if (profileSocials) profileSocials.value = p.socials || '';
  } catch {}
}

function renderChatApproval(){
  if (!chatApproval) return;
  if (!pendingSession){ chatApproval.style.display='none'; chatApproval.innerHTML=''; return; }
  chatApproval.style.display='block';
  const s = pendingSession;
  chatApproval.innerHTML = `
    <div>
      <div style="font-weight:600; color: var(--gold);">Connect Hive?</div>
      <div style="font-size:12px; color: var(--muted); margin-top:4px;">
        <div><strong>App:</strong> ${s.appOrigin || 'unknown'}</div>
        <div><strong>Persona:</strong> ${s.requestedPersona || 'default'}</div>
        <div><strong>Scopes:</strong> ${s.requestedScopes.join(', ')}</div>
      </div>
      <div style="display:flex; gap:8px; margin-top:8px;">
        <button id="approve-in-chat" class="btn approve">Approve</button>
        <button id="deny-in-chat" class="btn deny">Deny</button>
        <button id="customize-in-chat" class="btn">Customize</button>
      </div>
    </div>
  `;
  const approveBtn = document.getElementById('approve-in-chat') as HTMLButtonElement | null;
  const denyBtn = document.getElementById('deny-in-chat') as HTMLButtonElement | null;
  const customizeBtn = document.getElementById('customize-in-chat') as HTMLButtonElement | null;
  approveBtn?.addEventListener('click', async ()=>{ await approveSession(); renderChatApproval(); });
  denyBtn?.addEventListener('click', ()=>{
    pendingSession = null;
    chrome.storage.local.remove(["hive_pending_session"]);
    renderSession();
    renderChatApproval();
  });
  customizeBtn?.addEventListener('click', ()=>{ switchTab('config'); });
}

function getOriginsForProvider(p: ProviderId): string[] {
  if (p === 'openai') return ['https://chatgpt.com/*','https://*.openai.com/*'];
  if (p === 'claude') return ['https://claude.ai/*'];
  if (p === 'grok') return ['https://x.ai/*'];
  if (p === 'gemini') return ['https://gemini.google.com/*','https://*.google.com/*'];
  if (p === 'deepseek') return ['https://deepseek.com/*','https://*.deepseek.com/*'];
  return [];
}

useWebSessionEl?.addEventListener('change', async ()=>{
  const active = (providerSelect?.value || 'openai') as ProviderId;
  const on = !!useWebSessionEl?.checked;
  if (on) {
    const origins = getOriginsForProvider(active);
    if (!origins.length) { alert('Web session not supported for this provider'); useWebSessionEl.checked = false; return; }
    try {
      chrome.permissions.request({ origins }, async (granted: boolean)=>{
        if (granted) {
          await setUseWebSession(active, true);
          if (providerTokenInput) providerTokenInput.disabled = true;
        } else {
          useWebSessionEl.checked = false;
          await setUseWebSession(active, false);
          alert('Permission not granted. Web session disabled.');
        }
      });
    } catch {
      useWebSessionEl.checked = false;
      await setUseWebSession(active, false);
    }
  } else {
    await setUseWebSession(active, false);
    if (providerTokenInput) providerTokenInput.disabled = false;
  }
});

saveProfileBtn?.addEventListener('click', async ()=>{
  const p = {
    personality: (profilePersonality?.value || '').trim(),
    allergies: (profileAllergies?.value || '').trim(),
    preferences: (profilePreferences?.value || '').trim(),
    location: (profileLocation?.value || '').trim(),
    interests: (profileInterests?.value || '').trim(),
    education: (profileEducation?.value || '').trim(),
    socials: (profileSocials?.value || '').trim(),
  };
  await setUserProfile(p);
  alert('Profile saved');
});

function compressSnapshot(persona: any, user: any){
  const clamp = (s:string,n:number)=> (s||'').toString().slice(0,n);
  return {
    name: clamp(persona?.name, 60),
    tone: { formality: Number(persona?.tone?.formality ?? 50), concision: Number(persona?.tone?.concision ?? 50) },
    keywords: clamp(persona?.keywords || '', 200),
    bio: clamp(persona?.bio || '', 200),
    rules: clamp(persona?.rules || '', 300),
    user: {
      personality: clamp(user?.personality || '', 500),
      allergies: clamp(user?.allergies || '', 200),
      preferences: clamp(user?.preferences || '', 400),
      location: clamp(user?.location || '', 100),
      interests: clamp(user?.interests || '', 300),
      education: clamp(user?.education || '', 200),
      socials: clamp(user?.socials || '', 300)
    },
    ts: Date.now()
  };
}

genSignedPersonaBtn?.addEventListener('click', async ()=>{
  try {
    const persona = await getPersonaProfile();
    const user = await getUserProfile();
    const snapshot = compressSnapshot(persona, user);
    const data = JSON.stringify(snapshot);
    const sig = await signStringES256(data);
    await new Promise((res)=>chrome.storage.local.set({ hive_signed_persona: { snapshot, sig } }, ()=>res(null)));
    alert('Signed persona generated and stored.');
  } catch (e) { alert('Failed: ' + String(e)); }
});

copyPublicKeyBtn?.addEventListener('click', async ()=>{
  try {
    const jwk = await getPublicKeyJwk();
    await navigator.clipboard.writeText(JSON.stringify(jwk));
    alert('Public key copied');
  } catch (e) { alert('Copy failed: ' + String(e)); }
});

async function refreshConsents(){
  try {
    const logs = await getConsentLogs();
    if (!consentList) return;
    if (!logs.length){ consentList.innerHTML = 'No sites have access yet.'; return; }
    const rows = logs.map(e=>{
      const when = new Date(e.ts).toLocaleString();
      const scopes = (e.scopes||[]).join(', ');
      return `<div style=\"display:flex; align-items:center; justify-content:space-between; gap:8px; padding:6px 0; border-bottom:1px solid var(--outline);\">\n        <div>\n          <div style=\"font-weight:600; color:#ddd;\">${e.domain}</div>\n          <div style=\"font-size:12px; color:var(--muted);\">${scopes || 'minimal'} • ${when}</div>\n        </div>\n        <button class=\"btn\" data-revoke=\"${e.domain}\">Revoke</button>\n      </div>`;
    }).join('');
    consentList.innerHTML = rows;
  } catch { if (consentList) consentList.textContent = 'Error loading'; }
}

refreshConsentsBtn?.addEventListener('click', ()=>{ void refreshConsents(); });

grantCurrentBtn?.addEventListener('click', ()=>{
  try {
    chrome.tabs.query({ active:true, currentWindow:true }, async (tabs:any[])=>{
      const u = tabs && tabs[0] && tabs[0].url; if (!u) return alert('No active tab URL');
      let host = '';
      try { host = new URL(u).hostname; } catch { return alert('Invalid tab URL'); }
      await addConsent(host, ['persona:minimal']);
      alert('Granted minimal share for ' + host);
      void refreshConsents();
    });
  } catch { /* noop */ }
});

consentList?.addEventListener('click', async (ev)=>{
  const t = ev.target as HTMLElement;
  if (t && t.matches('button[data-revoke]')){
    const domain = t.getAttribute('data-revoke') || '';
    if (!domain) return;
    await removeConsent(domain);
    void refreshConsents();
  }
});

function switchTab(which: 'chat'|'config'|'profile'){
  if (!tabChat || !tabConfig || !tabChatBtn || !tabConfigBtn || !tabProfile) return;
  if (which === 'chat'){
    tabChat.style.display = '';
    tabConfig.style.display = 'none';
    tabProfile.style.display = 'none';
    tabChatBtn.classList.add('active');
    tabConfigBtn.classList.remove('active');
    tabProfileBtn?.classList.remove('active');
  } else {
    tabChat.style.display = 'none';
    tabChatBtn.classList.remove('active');
    if (which === 'config'){
      tabConfig.style.display = '';
      tabProfile.style.display = 'none';
      tabConfigBtn.classList.add('active');
      tabProfileBtn?.classList.remove('active');
    } else {
      tabConfig.style.display = 'none';
      tabProfile.style.display = '';
      tabConfigBtn.classList.remove('active');
      tabProfileBtn?.classList.add('active');
    }
  }
}

async function tryHandleIntent(q: string): Promise<boolean> {
  const text = q.trim();
  const lower = text.toLowerCase();
  const p = await getPersonaProfile();
  let changed = false;

  // set tone/formality to N or set tone to casual/formal [N]
  let m = lower.match(/set\s+(tone|formality)\s+to\s+(\d{1,3})/);
  if (m) {
    const val = Math.max(0, Math.min(100, parseInt(m[2], 10)));
    p.tone = p.tone || { formality: 50, concision: 50 } as any;
    (p.tone as any).formality = val;
    changed = true;
  } else if ((m = lower.match(/set\s+tone\s+to\s+(casual|formal)(?:\s+(\d{1,3}))?/))) {
    const kind = m[1];
    const val = m[2] ? Math.max(0, Math.min(100, parseInt(m[2], 10))) : (kind === 'casual' ? 30 : 70);
    p.tone = p.tone || { formality: 50, concision: 50 } as any;
    (p.tone as any).formality = val;
    changed = true;
  }

  // set concision to N
  m = lower.match(/set\s+concision\s+to\s+(\d{1,3})/);
  if (m) {
    const val = Math.max(0, Math.min(100, parseInt(m[1], 10)));
    p.tone = p.tone || { formality: 50, concision: 50 } as any;
    (p.tone as any).concision = val;
    changed = true;
  }

  // add keyword(s): list
  m = lower.match(/add\s+keywords?:\s+(.+)/);
  if (m) {
    const add = m[1].split(',').map(s=>s.trim()).filter(Boolean);
    const cur = (p.keywords || '').split(',').map(s=>s.trim()).filter(Boolean);
    const set = Array.from(new Set(cur.concat(add)));
    p.keywords = set.join(', ');
    changed = true;
  }

  // set keywords: list
  m = lower.match(/set\s+keywords?:\s+(.+)/);
  if (m) {
    const list = m[1].split(',').map(s=>s.trim()).filter(Boolean);
    p.keywords = list.join(', ');
    changed = true;
  }

  // set bio: text
  m = lower.match(/set\s+bio:\s+(.+)/);
  if (m) {
    p.bio = text.slice(text.toLowerCase().indexOf('set bio:') + 'set bio:'.length).trim();
    changed = true;
  }

  // set rules: text
  m = lower.match(/set\s+rules?:\s+(.+)/);
  if (m) {
    p.rules = text.slice(text.toLowerCase().indexOf('set rule') + (lower.includes('rules:')?'set rules:'.length:'set rule:'.length)).trim();
    changed = true;
  }

  if (!changed) return false;
  await setPersonaProfile(p);
  chatMessages.push({ role:'assistant', content: 'Persona updated.' });
  renderChat();
  try { chrome.storage.local.set({ hive_popup_chat_log: chatMessages.slice(-100) }); } catch {}
  return true;
}

function renderUser() {
  chrome.storage.local.get(["hive_extension_user"], (items: any) => {
    const user = items["hive_extension_user"];
    if (!user) {
      userInfo.textContent = "No user stored. (Use dev button)";
    } else {
      userInfo.textContent = `${user.displayName ?? user.userId}`;
    }
  });

personaFormality?.addEventListener("input", () => {
  if (valFormality) valFormality.textContent = personaFormality.value;
});
personaConcision?.addEventListener("input", () => {
  if (valConcision) valConcision.textContent = personaConcision.value;
});

savePersonaBtn?.addEventListener("click", async () => {
  const p = {
    name: (personaName?.value || "My Hive").trim(),
    tone: {
      formality: Number(personaFormality?.value || 50),
      concision: Number(personaConcision?.value || 50)
    },
    keywords: (personaKeywords?.value || "").trim(),
    bio: (personaBio?.value || "").trim(),
    rules: (personaRules?.value || "").trim()
  };
  await setPersonaProfile(p);
  alert("Persona saved");
});
}

async function initProviderUI() {
  const reg = await getRegistry();
  if (providerSelect) providerSelect.value = reg.active || "openai";
  if (providerTokenInput) providerTokenInput.value = reg.tokens?.[reg.active as ProviderId] || "";
  // Reflect encrypted token presence
  const existing = await getProviderToken(reg.active as ProviderId);
  if (secureStatus) secureStatus.textContent = existing ? "Stored securely" : "Not saved";
  if (providerModelInput) providerModelInput.value = (reg.prefModels?.[reg.active as ProviderId] || "");
  updateTokenLabel();
  try {
    const w = await getUseWebSession(reg.active as ProviderId);
    if (useWebSessionEl) useWebSessionEl.checked = !!w;
    if (providerTokenInput) providerTokenInput.disabled = !!w;
  } catch {}
  // Render consents
  void refreshConsents();
  // Behavior toggles
  try { chrome.storage.local.get(['hive_auto_tune_persona'], (i:any)=>{ if (autoTuneEl) autoTuneEl.checked = !!i['hive_auto_tune_persona']; }); } catch {}
  try { chrome.storage.local.get(['hive_capture_page'], (i:any)=>{ if (capturePageEl) capturePageEl.checked = !!i['hive_capture_page']; }); } catch {}
}

async function initPersonaUI() {
  const p = await getPersonaProfile();
  if (personaName) personaName.value = p.name || "";
  if (personaFormality) personaFormality.value = String(p.tone?.formality ?? 50);
  if (personaConcision) personaConcision.value = String(p.tone?.concision ?? 50);
  if (valFormality) valFormality.textContent = String(p.tone?.formality ?? 50);
  if (valConcision) valConcision.textContent = String(p.tone?.concision ?? 50);
  if (personaKeywords) personaKeywords.value = p.keywords || "";
  if (personaBio) personaBio.value = p.bio || "";
  if (personaRules) personaRules.value = p.rules || "";
}

chrome.runtime.onMessage.addListener((msg: any) => {
  if (msg?.type === "SHOW_SESSION_REQUEST") {
    pendingSession = msg.payload as SessionRequest;
    renderSession();
    renderChatApproval();
  }
  if (msg?.type === 'HIVE_SESSION_APPROVED'){
    try { (window as any).__hiveSessionToken = msg.payload?.token; } catch {}
    try { chatMessages.push({ role:'system', content:'Connected: session approved' }); renderChat(); try { chrome.storage.local.set({ hive_popup_chat_log: chatMessages.slice(-100) }); } catch {} } catch {}
    void refreshConn();
  }
});

// Initialize from storage in case popup opened before runtime message arrives
chrome.storage.local.get(["hive_pending_session"], (items: any) => {
  const s = items["hive_pending_session"] as SessionRequest | undefined;
  if (s) {
    pendingSession = s;
    renderSession();
    chrome.storage.local.remove(["hive_pending_session"]);
    renderChatApproval();
  }
});

// Initialize provider UI on load
void initProviderUI();
void initPersonaUI();
void initUserProfileUI();
switchTab('chat');
loadChatLog();
renderChat();
attemptSync();
// OAuth inputs persistence (Google/Gemini)
try {
  chrome.storage.local.get(['hive_google_client_id','hive_google_scopes'], (i:any)=>{
    const def = getDefaultGoogleOAuth();
    const cid = i['hive_google_client_id'] || def.clientId || '';
    const scopes = i['hive_google_scopes'] || def.scopes || 'https://www.googleapis.com/auth/generative-language';
    if (googleClientIdInput) googleClientIdInput.value = cid;
    if (googleScopesInput) googleScopesInput.value = scopes;
    if (cid) {
      // Hide manual config if default is present
      const btn = document.getElementById('save-google-oauth');
      const row = btn?.closest('.row') as HTMLElement | null;
      if (row) row.style.display = 'none';
    }
  });
} catch {}
// Init context badge
function refreshCtxSize(){ try { chrome.storage.local.get(['hive_last_context_size'], (i:any)=>{ const n = Number(i['hive_last_context_size'] || 0); if (ctxSizeEl) ctxSizeEl.textContent = String(n); }); } catch {} }
refreshCtxSize();
try { chrome.storage.onChanged.addListener((changes:any)=>{ if (changes && changes['hive_last_context_size']) refreshCtxSize(); }); } catch {}

// Connection status
async function refreshConn(){
  try {
    chrome.runtime.sendMessage({ type: 'HIVE_CHECK_CONN' }, (resp:any)=>{
      if (!connStatusEl) return;
      if (!resp || !resp.ok){ connStatusEl.textContent = 'Not connected'; return; }
      const { active, hasKey, webEnabled, webTabs } = resp;
      const mode = webEnabled ? (webTabs>0 ? 'Web Session' : 'Web Session (no tab)') : (hasKey ? 'API Key' : 'none');
      const connected = webEnabled ? (webTabs>0) : hasKey;
      connStatusEl.textContent = connected ? `Connected: ${active} • ${mode}` : `Configured: ${active} • ${mode}`;
    });
  } catch {}
}
void refreshConn();

// Minimize/Close buttons
btnMin?.addEventListener('click', ()=>{ try { document.body.classList.toggle('min'); } catch {} });
btnClose?.addEventListener('click', ()=>{ try { window.close(); } catch {} });

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
  const singleUseWrap = document.createElement("div");
  const singleUse = document.createElement("input");
  singleUse.type = "checkbox";
  singleUse.id = "single-use";
  singleUse.checked = true;
  const singleUseLabel = document.createElement("label");
  singleUseLabel.htmlFor = "single-use";
  singleUseLabel.textContent = " Single-use token";
  singleUseWrap.appendChild(singleUse);
  singleUseWrap.appendChild(singleUseLabel);

  const approveBtn = document.createElement("button");
  approveBtn.className = "btn approve";
  approveBtn.textContent = "Approve";
  approveBtn.onclick = async () => { await approveSession(); };

  const denyBtn = document.createElement("button");
  denyBtn.className = "btn deny";
  denyBtn.textContent = "Deny";
  denyBtn.onclick = () => {
    pendingSession = null;
    chrome.storage.local.remove(["hive_pending_session"]);
    renderSession();
    renderChatApproval();
  };

  div.appendChild(singleUseWrap);
  div.appendChild(approveBtn);
  div.appendChild(denyBtn);
  sessionList.appendChild(div);
}

async function approveSession() {
  if (!pendingSession) return;
  const reqOrigin = pendingSession.appOrigin || '';
  let user = await new Promise<any>((res) => chrome.storage.local.get(["hive_extension_user"], (i:any) => res(i["hive_extension_user"])));
  if (!user) {
    // Create a minimal local user so approval doesn't get stuck
    user = { userId: `guest_${Math.random().toString(36).slice(2,8)}`, displayName: "Guest" };
    try { await new Promise((res)=> chrome.storage.local.set({ hive_extension_user: user }, ()=> res(null))); } catch {}
  }
  const createResp = await new Promise<any>((res) => {
    chrome.runtime.sendMessage({
      type: "HIVE_CREATE_TOKEN",
      payload: { userId: user.userId, sessionId: pendingSession!.sessionId, scopes: pendingSession!.requestedScopes, origin: pendingSession!.appOrigin, singleUse: (document.getElementById("single-use") as HTMLInputElement)?.checked ?? false }
    }, (resp: any) => { res(resp); });
  });
  if (!createResp || !createResp.ok || !createResp.token) {
    alert('Approval failed: ' + (createResp?.error || 'unknown'));
    return;
  }
  const signedToken: ClientSignedToken = createResp.token;

  try {
    // Capture requesting tab before clearing keys
    const meta: any = await new Promise((res)=> chrome.storage.local.get(['hive_pending_session_tab'], (i:any)=> res(i && i['hive_pending_session_tab'])));
    // Clear pending keys to stop poll repaint
    await new Promise((res)=> chrome.storage.local.remove(["hive_pending_session","hive_pending_session_tab"], ()=> res(null)));
    // Update local state
    pendingSession = null;
    renderSession();
    renderChatApproval();
    // Helper to safely send to a tab
    const safeSend = (id:number)=>{ try { chrome.tabs.sendMessage(id, { type: 'HIVE_SESSION_APPROVED', payload: { token: signedToken } }, ()=>{ try { chrome.runtime.lastError; } catch {} }); } catch {} };
    // Notify specific tab first
    if (meta && typeof meta.tabId === 'number') safeSend(meta.tabId);
    // Then target tabs by origin pattern if available
    let targeted = 0;
    try {
      if (reqOrigin && /^https?:\/\//.test(reqOrigin)){
        const u = new URL(reqOrigin);
        const pat = `${u.protocol}//${u.host}/*`;
        chrome.tabs.query({ url: [pat] }, (tabs:any[])=>{ for(const t of tabs||[]){ targeted++; safeSend(t.id); } });
      }
    } catch {}
    // Fallback: broadcast only if nothing was targeted
    if (!targeted){
      try {
        chrome.tabs.query({}, (tabs: any[]) => { for (const t of tabs || []) safeSend(t.id); });
      } catch {}
    }
  } catch {}
}

setSample.addEventListener("click", () => {
  const sampleUser = { userId: "larry_omakh", displayName: "Larry Omakh", providerTokens: { openai: "REPLACE_WITH_REAL_TOKEN" } };
  chrome.storage.local.set({ hive_extension_user: sampleUser }, () => {
    renderUser();
    alert("Sample user stored (dev). Replace token in real flow.");
  });
});

providerSelect?.addEventListener("change", async () => {
  const active = providerSelect!.value as ProviderId;
  await setActiveProvider(active);
  const reg = await getRegistry();
  if (providerTokenInput) providerTokenInput.value = reg.tokens?.[active as ProviderId] || "";
  const existing = await getProviderToken(active);
  if (secureStatus) secureStatus.textContent = existing ? "Stored securely" : "Not saved";
  updateTokenLabel();
  try {
    const w = await getUseWebSession(active);
    if (useWebSessionEl) useWebSessionEl.checked = !!w;
    if (providerTokenInput) providerTokenInput.disabled = !!w;
  } catch {}
});

saveTokenBtn?.addEventListener("click", async () => {
  const active = (providerSelect?.value || "openai") as ProviderId;
  const key = (providerTokenInput?.value || "").trim();
  await setProviderToken(active, key || undefined);
  if (secureStatus) secureStatus.textContent = key ? "Stored securely" : "Not saved";
  alert(key ? (active === 'local' ? "Base URL saved" : "Provider key saved") : "Provider key cleared");
});

clearTokenBtn?.addEventListener("click", async () => {
  if (providerTokenInput) providerTokenInput.value = "";
  const active = (providerSelect?.value || "openai") as ProviderId;
  await setProviderToken(active, undefined);
  if (secureStatus) secureStatus.textContent = "Not saved";
  alert("Provider key cleared");
});

saveModelBtn?.addEventListener("click", async () => {
  const active = (providerSelect?.value || "gemini") as ProviderId;
  const model = (providerModelInput?.value || "").trim();
  await setPreferredModel(active, model || undefined);
  alert(model ? "Preferred model saved" : "Preferred model cleared");
});

listModelsBtn?.addEventListener("click", async () => {
  chrome.runtime.sendMessage({ type: "HIVE_LIST_MODELS" }, (resp:any) => {
    if (resp?.ok) {
      const names = [
        ...(Array.isArray(resp.v1?.models) ? resp.v1.models.map((m:any)=>m.name) : []),
        ...(Array.isArray(resp.v1beta?.models) ? resp.v1beta.models.map((m:any)=>m.name) : []),
      ];
      alert(names.length ? names.join("\n") : "No models found for this key");
    } else {
      alert("List Models failed: " + (resp?.error || "unknown"));
    }
  });
});

revokeLast?.addEventListener("click", () => {
  chrome.storage.local.get(["hive_last_session_id"], (i:any) => {
    const sessionId = i["hive_last_session_id"];
    if (!sessionId) return alert("No last session recorded.");
    chrome.runtime.sendMessage({ type: "HIVE_REVOKE_TOKEN", payload: { sessionId } }, (resp:any) => {
      if (resp?.ok) alert("Last session revoked");
      else alert("Revoke failed");
    });
  });
});

debugInfoBtn?.addEventListener("click", () => {
  chrome.runtime.sendMessage({ type: "HIVE_DEBUG_INFO" }, (resp:any) => {
    if (resp?.ok) {
      alert(JSON.stringify(resp.debug, null, 2));
    } else {
      alert("Debug request failed");
    }
  });
});

renderUser();
renderSession();
tabChatBtn?.addEventListener('click', ()=> switchTab('chat'));
tabConfigBtn?.addEventListener('click', ()=> switchTab('config'));
tabProfileBtn?.addEventListener('click', ()=> switchTab('profile'));

async function sendChat(){
  const q = (chatInput?.value || '').trim();
  if (!q) return;
  chatInput!.value = '';
  chatMessages.push({ role: 'user', content: q });
  renderChat();
  if (chatSend) chatSend.disabled = true;
  // Persist chat log (lightweight)
  try { chrome.storage.local.set({ hive_popup_chat_log: chatMessages.slice(-100) }); } catch {}
  // Record memory event (user-originated)
  try { chrome.runtime.sendMessage({ type: 'HIVE_RECORD_MEMORY', payload: { origin: 'popup', event: { source:'user', type:'popup_chat', text: q } } }); } catch {}

  // Intent parsing to edit Persona directly via chat
  const handled = await tryHandleIntent(q);
  if (handled){ if (chatSend) chatSend.disabled = false; return; }

  chrome.runtime.sendMessage({ type: 'HIVE_POPUP_CHAT', payload: { messages: chatMessages } }, (resp: any)=>{
    if (!resp || !resp.ok){
      chatMessages.push({ role: 'assistant', content: resp?.error ? String(resp.error) : 'Chat failed. Check provider in Config.' });
    } else {
      chatMessages.push({ role: 'assistant', content: resp.text || '(no text)' });
      // Record assistant reply to memory bus
      try { chrome.runtime.sendMessage({ type:'HIVE_RECORD_MEMORY', payload: { origin:'popup', event: { source:'gpt', role:'assistant', type:'popup_chat', text: resp.text || '' } } }); } catch {}
    }
    renderChat();
    if (chatSend) chatSend.disabled = false;
    try { chrome.storage.local.set({ hive_popup_chat_log: chatMessages.slice(-100) }); } catch {}
  });
}

// Click handling is managed by unified primary handler below
chatInput?.addEventListener('keydown', (e)=>{
  if (e.key === 'Enter') {
    e.preventDefault();
    if (actionMode === 'send') return void sendChat();
    if (actionMode === 'insert') return void pushToPage(false);
    if (actionMode === 'insert_send') return void pushToPage(true);
  }
});

// Unified action button mode
type ActionMode = 'send' | 'insert' | 'insert_send';
let actionMode: ActionMode = 'send';

function setActionMode(mode: ActionMode){
  actionMode = mode;
  // Persist
  try { chrome.storage.local.set({ hive_action_mode: mode }); } catch {}
  updateActionUI();
}

function updateActionUI(){
  if (actionPrimaryBtn){
    actionPrimaryBtn.textContent = actionMode === 'send' ? 'Send' : (actionMode === 'insert' ? 'Insert' : 'Insert & Send');
  }
  if (actionMenuEl){
    const btns = Array.from(actionMenuEl.querySelectorAll('button[data-mode]')) as HTMLButtonElement[];
    for (const b of btns){ b.classList.toggle('active', b.getAttribute('data-mode') === actionMode); }
  }
}

// Load stored action mode
try { chrome.storage.local.get(['hive_action_mode'], (i:any)=>{ const m = i['hive_action_mode']; if (m === 'send' || m === 'insert' || m === 'insert_send') { actionMode = m; updateActionUI(); } }); } catch {}

// Toggle dropdown
actionModeBtn?.addEventListener('click', ()=>{ try { if (actionMenuEl) actionMenuEl.classList.toggle('open'); } catch {} });
document.addEventListener('click', (ev)=>{ const t = ev.target as HTMLElement; if (!t) return; const menu = actionMenuEl; const modeBtn = actionModeBtn; if (!menu) return; if (t === menu || menu.contains(t) || t === modeBtn) return; menu.classList.remove('open'); });

// Select mode from menu
actionMenuEl?.addEventListener('click', (ev)=>{
  const t = ev.target as HTMLElement;
  if (t && t.matches('button[data-mode]')){
    const m = t.getAttribute('data-mode') as ActionMode;
    setActionMode(m);
    if (actionMenuEl) actionMenuEl.classList.remove('open');
  }
});

// Primary action click executes according to mode
actionPrimaryBtn?.addEventListener('click', ()=>{
  if (actionMode === 'send') return void sendChat();
  if (actionMode === 'insert') return void pushToPage(false);
  if (actionMode === 'insert_send') return void pushToPage(true);
});

function lastAssistantText(): string {
  for (let i = chatMessages.length - 1; i >= 0; i--) {
    if (chatMessages[i].role === 'assistant') return chatMessages[i].content || '';
  }
  return '';
}

function pushToPage(send:boolean){
  try {
    const text = lastAssistantText();
    if (!text) { alert('No assistant message to insert'); return; }
    // Target active provider tab
    chrome.runtime.sendMessage({ type: 'HIVE_CHECK_CONN' }, (resp:any)=>{
      const active = resp?.active || 'openai';
      const origins: Record<string,string[]> = {
        openai: ['https://chatgpt.com/*','https://*.openai.com/*'],
        claude: ['https://claude.ai/*'],
        gemini: ['https://gemini.google.com/*','https://*.google.com/*'],
        grok: ['https://x.ai/*'],
        deepseek: ['https://deepseek.com/*','https://*.deepseek.com/*']
      };
      const pats = origins[active] || [];
      chrome.tabs.query({ url: pats.length ? pats : undefined }, (tabs:any[])=>{
        if (!tabs || !tabs.length) { alert('No provider tab found.'); return; }
        const id = tabs[0].id;
        try { chrome.tabs.sendMessage(id, { type: 'HIVE_INSERT_TEXT', payload: { text, send } }, ()=>{ try { chrome.runtime.lastError; } catch {} }); } catch {}
        // Record insert action to memory bus (summary)
        try { chrome.runtime.sendMessage({ type:'HIVE_RECORD_MEMORY', payload: { origin:'popup', event: { source:'popup', type: send ? 'insert_and_send' : 'insert_text', text } } }); } catch {}
      });
    });
  } catch {}
}

insertBtn?.addEventListener('click', ()=> pushToPage(false));
insertSendBtn?.addEventListener('click', ()=> pushToPage(true));

function updateTokenLabel() {
  const active = (providerSelect?.value || "openai") as ProviderId;
  const label = document.getElementById("provider-token-label");
  if (!label) return;
  label.textContent = (active === 'local' || active === 'grok') ? 'Base URL' : 'API Key';
}
