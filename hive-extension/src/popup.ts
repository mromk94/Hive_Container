import type { SessionRequest, ClientSignedToken } from "./types";
import type { ProviderId } from "./registry";
import { getRegistry, setActiveProvider, setProviderToken, setPreferredModel, getProviderToken, getPersonaProfile, setPersonaProfile } from "./registry";

declare const chrome: any;

const sessionList = document.getElementById("session-list")!;
const userInfo = document.getElementById("user-info")!;
const setSample = document.getElementById("set-sample-user")!;
// Tabs & Chat UI
const tabChatBtn = document.getElementById("tabbtn-chat") as HTMLButtonElement | null;
const tabConfigBtn = document.getElementById("tabbtn-config") as HTMLButtonElement | null;
const tabChat = document.getElementById("tab-chat") as HTMLDivElement | null;
const tabConfig = document.getElementById("tab-config") as HTMLDivElement | null;
const chatLog = document.getElementById("chat-log") as HTMLDivElement | null;
const chatInput = document.getElementById("chat-input") as HTMLInputElement | null;
const chatSend = document.getElementById("chat-send") as HTMLButtonElement | null;
const chatApproval = document.getElementById("chat-approval") as HTMLDivElement | null;
const ctxSizeEl = document.getElementById('ctx-size') as HTMLSpanElement | null;
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
// OAuth buttons
const oauthOpenAI = document.getElementById('oauth-openai') as HTMLButtonElement | null;
const oauthGemini = document.getElementById('oauth-gemini') as HTMLButtonElement | null;
const oauthClaude = document.getElementById('oauth-claude') as HTMLButtonElement | null;
const oauthGrok = document.getElementById('oauth-grok') as HTMLButtonElement | null;
const oauthDeepseek = document.getElementById('oauth-deepseek') as HTMLButtonElement | null;
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

let pendingSession: SessionRequest | null = null;

type ChatMessage = { role: 'user'|'assistant'|'system'; content: string };
const chatMessages: ChatMessage[] = [];

function renderChat() {
  if (!chatLog) return;
  chatLog.innerHTML = "";
  for (const m of chatMessages) {
    const row = document.createElement('div'); row.className = 'msg';
    const who = document.createElement('div'); who.className = 'who'; who.textContent = m.role === 'assistant' ? 'Hive' : (m.role === 'user' ? 'You' : 'System');
    const bub = document.createElement('div'); bub.className = 'bubble'; bub.textContent = m.content;
    row.appendChild(who); row.appendChild(bub);
    chatLog.appendChild(row);
  }
  chatLog.scrollTop = chatLog.scrollHeight;
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

function switchTab(which: 'chat'|'config'){
  if (!tabChat || !tabConfig || !tabChatBtn || !tabConfigBtn) return;
  if (which === 'chat'){
    tabChat.style.display = '';
    tabConfig.style.display = 'none';
    tabChatBtn.classList.add('active');
    tabConfigBtn.classList.remove('active');
  } else {
    tabChat.style.display = 'none';
    tabConfig.style.display = '';
    tabChatBtn.classList.remove('active');
    tabConfigBtn.classList.add('active');
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
switchTab('chat');
renderChat();
// Restore chat log
try { chrome.storage.local.get(['hive_popup_chat_log'], (i:any)=>{ const arr = Array.isArray(i['hive_popup_chat_log']) ? i['hive_popup_chat_log'] : []; if (arr.length){ (chatMessages as any).splice(0, chatMessages.length, ...arr); renderChat(); } }); } catch {}
// Init context badge
function refreshCtxSize(){ try { chrome.storage.local.get(['hive_last_context_size'], (i:any)=>{ const n = Number(i['hive_last_context_size'] || 0); if (ctxSizeEl) ctxSizeEl.textContent = String(n); }); } catch {} }
refreshCtxSize();
try { chrome.storage.onChanged.addListener((changes:any)=>{ if (changes && changes['hive_last_context_size']) refreshCtxSize(); }); } catch {}

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
  const user = await new Promise<any>((res) => chrome.storage.local.get(["hive_extension_user"], (i:any) => res(i["hive_extension_user"])));
  if (!user) {
    alert("No user set. Use dev button to set a sample user.");
    return;
  }
  const signedToken = await new Promise<ClientSignedToken>((res) => {
    chrome.runtime.sendMessage({
      type: "HIVE_CREATE_TOKEN",
      payload: { userId: user.userId, sessionId: pendingSession!.sessionId, scopes: pendingSession!.requestedScopes, origin: pendingSession!.appOrigin, singleUse: (document.getElementById("single-use") as HTMLInputElement)?.checked ?? false }
    }, (resp: any) => { res(resp.token); });
  });

  chrome.tabs.query({ active: true, currentWindow: true }, (tabs: any[]) => {
    if (!tabs || tabs.length === 0) return;
    chrome.tabs.sendMessage(tabs[0].id, { type: "HIVE_SESSION_APPROVED", payload: { token: signedToken } });
  });

  pendingSession = null;
  chrome.storage.local.remove(["hive_pending_session"]);
  renderSession();
  renderChatApproval();
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

async function sendChat(){
  const q = (chatInput?.value || '').trim();
  if (!q) return;
  chatInput!.value = '';
  chatMessages.push({ role: 'user', content: q });
  renderChat();
  if (chatSend) chatSend.disabled = true;
  // Persist chat log (lightweight)
  try { chrome.storage.local.set({ hive_popup_chat_log: chatMessages.slice(-100) }); } catch {}

  // Intent parsing to edit Persona directly via chat
  const handled = await tryHandleIntent(q);
  if (handled){ if (chatSend) chatSend.disabled = false; return; }

  chrome.runtime.sendMessage({ type: 'HIVE_POPUP_CHAT', payload: { messages: chatMessages } }, (resp: any)=>{
    if (!resp || !resp.ok){
      chatMessages.push({ role: 'assistant', content: resp?.error ? String(resp.error) : 'Chat failed. Check provider in Config.' });
    } else {
      chatMessages.push({ role: 'assistant', content: resp.text || '(no text)' });
    }
    renderChat();
    if (chatSend) chatSend.disabled = false;
    try { chrome.storage.local.set({ hive_popup_chat_log: chatMessages.slice(-100) }); } catch {}
  });
}

chatSend?.addEventListener('click', sendChat);
chatInput?.addEventListener('keydown', (e)=>{ if (e.key === 'Enter') { e.preventDefault(); sendChat(); } });

function updateTokenLabel() {
  const active = (providerSelect?.value || "openai") as ProviderId;
  const label = document.getElementById("provider-token-label");
  if (!label) return;
  label.textContent = (active === 'local' || active === 'grok') ? 'Base URL' : 'API Key';
}
