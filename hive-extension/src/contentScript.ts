// Content script bridge for Hive Container
// Bridges page window.postMessage <-> extension runtime messages


window.addEventListener(
  "message",
  (evt: MessageEvent) => {
    const data = (evt && evt.data) || null;
    if (!data || typeof data !== "object") return;
    const { source, payload } = data as { source?: string; payload?: any };

    if (source === "HIVE_CONNECT_REQUEST" && payload) {
      chrome.runtime.sendMessage(
        { type: "HIVE_SESSION_REQUEST", payload },
        (resp: { ok?: boolean } | undefined) => {
          window.postMessage(
            { source: "HIVE_CONNECT_RELAYED", payload: { ok: !!(resp && resp.ok) } },
            "*"
          );
        }
      );
    }

    if (source === "HIVE_FORWARD_REQUEST" && payload) {
      const raw = window.location.origin as string | undefined;
      const origin = raw && raw !== "null" ? raw : "file://";
      chrome.runtime.sendMessage(
        { type: "APP_FORWARD_REQUEST", payload: { ...payload, origin } },
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (resp: any) => {
          window.postMessage({ source: "HIVE_FORWARD_RESPONSE", payload: resp }, "*");
        }
      );
    }

    if (source === "HIVE_GET_PERSONA") {
      chrome.runtime.sendMessage(
        { type: "HIVE_GET_PERSONA" },
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (resp: any) => {
          window.postMessage({ source: "HIVE_PERSONA", payload: resp }, "*");
        }
      );
    }

    if (source === "HIVE_SUGGEST_REPLY" && payload) {
      const raw = window.location.origin as string | undefined;
      const origin = raw && raw !== "null" ? raw : "file://";
      chrome.runtime.sendMessage(
        { type: "HIVE_SUGGEST_REPLY", payload: { ...payload, origin } },
        // eslint-disable-next-line @typescript-eslint/no-explicit-any
        (resp: any) => {
          // surface background errors if no listener or exception
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          const err: any = (chrome as any)?.runtime?.lastError;
          const payloadOut = resp ?? { ok: false, error: err?.message || 'no_response' };
          window.postMessage({ source: "HIVE_SUGGESTIONS", payload: payloadOut }, "*");
        }
      );
    }
  },
  false
);

chrome.runtime.onMessage.addListener((msg: any) => {
  if (msg?.type === "HIVE_SESSION_APPROVED") {
    window.postMessage({ source: "HIVE_SESSION_APPROVED", payload: msg.payload }, "*");
    try { (window as any).__hiveSessionToken = msg.payload?.token; } catch {}
  }
  if (msg?.type === 'HIVE_SESSION_REVOKED') {
    try { (window as any).__hiveSessionToken = null; } catch {}
    try {
      const toast = document.createElement('div');
      toast.textContent = 'Hive session revoked';
      toast.setAttribute('style','position:fixed;right:16px;bottom:60px;z-index:2147483645;background:#111;color:#eee;border:1px solid #1b1b1b;border-radius:8px;padding:8px 10px;box-shadow:0 10px 20px rgba(0,0,0,.35);font-size:12px;opacity:0;transition:opacity .2s ease');
      document.documentElement.appendChild(toast);
      requestAnimationFrame(()=>{ toast.style.opacity='1'; setTimeout(()=>{ toast.style.opacity='0'; setTimeout(()=>toast.remove(), 250); }, 1200); });
    } catch {}
  }
  if (msg?.type === 'HIVE_SCRAPE_THREAD') {
    try {
      const host = location.hostname;
      const take = Math.max(2, Math.min(20, Number(msg?.payload?.take || 12)));
      const out: Array<{ role: 'user'|'assistant', content: string }> = [];
      const push = (role:string, text:string)=>{ const t = (text||'').trim(); if (!t) return; out.push({ role: role==='assistant'?'assistant':'user', content: t }); };
      if (/chatgpt\.com$|openai\.com$/.test(host)) {
        const nodes = Array.from(document.querySelectorAll('[data-message-author-role]')) as HTMLElement[];
        const last = nodes.slice(-take);
        for (const el of last){
          const role = (el.getAttribute('data-message-author-role') || '').toLowerCase();
          // Prefer visible message text blocks
          let text = '';
          const blocks = el.querySelectorAll('[data-message-text], .markdown, [data-testid^="conversation-turn-"]');
          if (blocks && blocks.length){
            text = Array.from(blocks).map(b=> (b as HTMLElement).innerText || (b as HTMLElement).textContent || '').join('\n').trim();
          } else {
            text = el.innerText || el.textContent || '';
          }
          push(role, text);
        }
      } else if (/gemini\.google\.com$/.test(host)) {
        // Best-effort Gemini selectors
        const chat = document.querySelector('[aria-live="polite"], main') || document.body;
        const items = Array.from(chat.querySelectorAll('[role="listitem"], article, div[aria-label]')) as HTMLElement[];
        const last = items.slice(-take);
        for (const el of last){
          const who = (el.getAttribute('data-source') || el.getAttribute('aria-label') || '').toLowerCase();
          const role = /user|you/.test(who) ? 'user' : 'assistant';
          const text = (el.innerText || el.textContent || '').trim();
          push(role, text);
        }
      } else {
        // Generic fallback: last text blocks in the main area
        const main = document.querySelector('main') || document.body;
        const paras = Array.from(main.querySelectorAll('p,li,article,section')) as HTMLElement[];
        const last = paras.slice(-take);
        for (const el of last){ push('assistant', el.innerText || el.textContent || ''); }
      }
      chrome.runtime.sendMessage({ type: 'HIVE_SCRAPE_THREAD_RESULT', payload: { ok: true, messages: out, origin: location.origin } });
    } catch (e) {
      chrome.runtime.sendMessage({ type: 'HIVE_SCRAPE_THREAD_RESULT', payload: { ok: false, error: String(e) } });
    }
  }
  if (msg?.type === 'HIVE_PROVIDER_PROXY') {
    (async ()=>{
      try {
        const { url, init, allowedOrigins } = msg.payload || {};
        const origin = window.location.origin;
        const allow = Array.isArray(allowedOrigins) && allowedOrigins.length ? allowedOrigins : [origin];
        if (!allow.some((a:string)=> origin.startsWith(a))) {
          return msg._sendResponse && msg._sendResponse({ ok:false, error:'origin_not_allowed' });
        }
        const opts: RequestInit = { method: init?.method || 'GET', headers: init?.headers || {}, body: init?.body, credentials: 'include', mode: 'cors' } as any;
        const resp = await fetch(url, opts);
        const ct = resp.headers.get('content-type') || '';
        let data: any = null;
        if (ct.includes('application/json')) { data = await resp.json(); }
        else { data = await resp.text(); }
        chrome.runtime.sendMessage({ type: 'HIVE_PROVIDER_PROXY_RESULT', payload: { id: msg.payload?.id, ok: resp.ok, status: resp.status, data } });
      } catch (e) {
        chrome.runtime.sendMessage({ type: 'HIVE_PROVIDER_PROXY_RESULT', payload: { id: msg.payload?.id, ok: false, error: String(e) } });
      }
    })();
  }
});

// Generic Chat Adapter v1
(() => {
  try {
    const style = document.createElement('style');
    style.textContent = `
      .hive-bubble{position:absolute; z-index:2147483646; font-family:system-ui,sans-serif;}
      .hive-btn{padding:6px 8px; border-radius:999px; border:1px solid #d4af37; background:linear-gradient(180deg, rgba(212,175,55,.18), rgba(212,175,55,.08)); color:#eee; cursor:pointer; box-shadow:0 6px 14px rgba(212,175,55,.18); font-size:12px}
      .hive-panel{position:absolute; z-index:2147483647; min-width:240px; max-width:360px; background:#0f0f0f; color:#eee; border:1px solid #1b1b1b; border-radius:10px; box-shadow:0 18px 32px rgba(0,0,0,.45); padding:8px}
      .hive-sugg{border:1px solid #1b1b1b; border-radius:8px; padding:8px; margin-top:6px; background:#111;}
      .hive-actions{display:flex; gap:6px; margin-top:6px}
      .hive-mini{font-size:11px; color:#999}
      .hive-banner{position:fixed; right:16px; bottom:16px; z-index:2147483645; background:#0f0f0f; color:#eee; border:1px solid #1b1b1b; border-radius:999px; padding:6px 10px; box-shadow:0 10px 20px rgba(0,0,0,.35); font-family:system-ui,sans-serif; font-size:12px; display:flex; gap:8px; align-items:center}
      .hive-dot{width:8px; height:8px; border-radius:50%; background:#2ecc71;}
      .hive-dot.paused{ background:#e74c3c; }
      .hive-toast{position:fixed; right:16px; bottom:60px; z-index:2147483645; background:#111; color:#eee; border:1px solid #1b1b1b; border-radius:8px; padding:8px 10px; box-shadow:0 10px 20px rgba(0,0,0,.35); font-size:12px; opacity:0; transition:opacity .2s ease}
      .hive-toast.show{opacity:1}
    `;
    document.documentElement.appendChild(style);

    let targetEl: HTMLElement | null = null;
    let paused = false;
    const originStr = (window.location.origin && window.location.origin !== 'null') ? window.location.origin : 'file://';
    function getPausedOrigins(cb:(arr:string[])=>void){ chrome.storage.local.get(['hive_paused_origins'], (i)=>{ const arr = Array.isArray(i['hive_paused_origins']) ? i['hive_paused_origins'] : []; cb(arr); }); }
    function setPausedOrigins(arr:string[], cb?:()=>void){ chrome.storage.local.set({ hive_paused_origins: arr }, ()=> cb && cb()); }
    function refreshPaused(cb?:()=>void){ getPausedOrigins((arr)=>{ paused = arr.includes(originStr); updateBanner(); cb && cb(); }); }
    function setPausedState(next:boolean){ getPausedOrigins((arr)=>{ const set = new Set(arr); if (next) set.add(originStr); else set.delete(originStr); setPausedOrigins(Array.from(set), ()=> refreshPaused()); }); }
    let sessionToken: any = (window as any).__hiveSessionToken || null;
    const bubble = document.createElement('div'); bubble.className='hive-bubble'; bubble.style.display='none';
    const btn = document.createElement('button'); btn.className='hive-btn'; btn.textContent='Use my Hive';
    const hydrateBtn = document.createElement('button'); hydrateBtn.className='hive-btn'; hydrateBtn.textContent='Hydrate';
    bubble.appendChild(btn);
    bubble.appendChild(hydrateBtn);
    document.documentElement.appendChild(bubble);
    // Prevent focus from leaving the editable field when clicking the bubble/button
    bubble.addEventListener('mousedown', (e)=>{ e.preventDefault(); });
    btn.addEventListener('mousedown', (e)=>{ e.preventDefault(); });
    hydrateBtn.addEventListener('mousedown', (e)=>{ e.preventDefault(); });

    const panel = document.createElement('div'); panel.className='hive-panel'; panel.style.display='none';
    panel.innerHTML = '<div class="hive-mini">Suggestions will appear here…</div>';
    document.documentElement.appendChild(panel);

    // Banner (active/paused)
    const banner = document.createElement('div'); banner.className='hive-banner';
    const dot = document.createElement('div'); dot.className='hive-dot';
    const label = document.createElement('div'); label.textContent = 'Hive: Active';
    const toggle = document.createElement('button'); toggle.className='hive-btn'; toggle.textContent='Pause';
    toggle.addEventListener('click', (e)=>{ e.stopPropagation(); setPausedState(!paused); });
    banner.appendChild(dot); banner.appendChild(label); banner.appendChild(toggle);
    document.documentElement.appendChild(banner);
    function updateBanner(){
      if (paused){ dot.classList.add('paused'); label.textContent='Hive: Paused'; toggle.textContent='Resume'; hideBubble(); hidePanel(); }
      else { dot.classList.remove('paused'); label.textContent='Hive: Active'; toggle.textContent='Pause'; }
    }
    refreshPaused();

    // Toast
    const toast = document.createElement('div'); toast.className='hive-toast'; toast.textContent='Context saved'; document.documentElement.appendChild(toast);
    function showToast(msg:string){ toast.textContent = msg; toast.classList.add('show'); setTimeout(()=> toast.classList.remove('show'), 1200); }

    function isEditable(n: Element | null): n is HTMLElement {
      if (!n || !(n as HTMLElement).focus) return false;
      const el = n as HTMLElement;
      if (el.tagName === 'TEXTAREA') return true;
      if (el.tagName === 'INPUT') {
        const t = (el as HTMLInputElement).type || 'text';
        return ['text','search','email','url','tel'].includes(t.toLowerCase());
      }
      if ((el as HTMLElement).isContentEditable) return true;
      return false;
    }

    function positionNear(el: HTMLElement, anchor: HTMLElement){
      const r = el.getBoundingClientRect();
      const top = window.scrollY + r.bottom - 8;
      const left = window.scrollX + r.right - 100;
      anchor.style.top = `${top}px`;
      anchor.style.left = `${left}px`;
    }

    function showBubble(el: HTMLElement){
      if (paused) return;
      targetEl = el;
      bubble.style.display='block';
      positionNear(el, bubble);
    }
    function hideBubble(){ bubble.style.display='none'; }
    function hidePanel(){ panel.style.display='none'; }

    document.addEventListener('focusin', (e)=>{
      const t = e.target as Element | null;
      if (isEditable(t)) showBubble(t as HTMLElement); else { hideBubble(); hidePanel(); }
    });
    document.addEventListener('scroll', ()=>{ if (targetEl) positionNear(targetEl, bubble); if (panel.style.display!=='none' && targetEl) positionNear(targetEl, panel); }, true);
    window.addEventListener('resize', ()=>{ if (targetEl) { positionNear(targetEl, bubble); positionNear(targetEl, panel); } });

    function getText(): string {
      if (!targetEl) return '';
      if ((targetEl as HTMLInputElement).value != null) return (targetEl as HTMLInputElement).value;
      if (targetEl.isContentEditable) return targetEl.textContent || '';
      return '';
    }
    function setText(v: string){
      if (!targetEl) return;
      if ((targetEl as HTMLInputElement).value != null) { (targetEl as HTMLInputElement).value = v; (targetEl as any).dispatchEvent(new Event('input',{bubbles:true})); return; }
      if (targetEl.isContentEditable) { targetEl.textContent = v; (targetEl as any).dispatchEvent(new Event('input',{bubbles:true})); }
    }

    // Share persona utilities
    function personaToText(snapshot:any): string {
      try {
        const parts: string[] = [];
        if (snapshot?.name) parts.push(`Name: ${snapshot.name}`);
        if (snapshot?.tone) parts.push(`Tone: f${snapshot.tone?.formality}/c${snapshot.tone?.concision}`);
        if (snapshot?.keywords) parts.push(`Keywords: ${snapshot.keywords}`);
        if (snapshot?.bio) parts.push(`Bio: ${snapshot.bio}`);
        const u = snapshot?.user || {};
        if (u.personality) parts.push(`Personality: ${u.personality}`);
        if (u.preferences) parts.push(`Preferences: ${u.preferences}`);
        if (u.location) parts.push(`Location: ${u.location}`);
        if (u.interests) parts.push(`Interests: ${u.interests}`);
        return parts.join(' | ').slice(0, 600);
      } catch { return ''; }
    }

    async function hashText(s: string): Promise<string> {
      try {
        const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
        return Array.from(new Uint8Array(buf)).map((b)=>b.toString(16).padStart(2,'0')).join('');
      } catch { return String(s.length) + ':' + (s||'').slice(0,16); }
    }

    function keyFor(name:string){ try { const o = (window.location.origin && window.location.origin !== 'null') ? window.location.origin : 'file://'; return `${name}_${o.replace(/[^a-z0-9_\.\-]/gi,'_')}`; } catch { return name; } }

    async function promptInjectPersona(snapshot:any){
      const text = personaToText(snapshot) || 'Use my saved persona context.';
      const sys = `SYSTEM: Use persona -> ${text}`;
      const lastHashKey = keyFor('hive_last_persona_hash');
      const hash = await hashText(sys.trim());
      let skip = false;
      try {
        const mem: any = await new Promise((res)=> chrome.storage.local.get([lastHashKey], (i)=> res(i)));
        const prev = mem && mem[lastHashKey];
        const wPrev = (window as any).__hiveLastPersonaHash;
        if (prev && prev === hash) skip = true;
        if (wPrev && wPrev === hash) skip = true;
      } catch {}
      if (skip) { showToast('Persona already injected'); return; }
      const cur = getText();
      setText(`${sys}\n\n${cur}`.trim());
      try { (window as any).__hiveLastPersonaHash = hash; chrome.storage.local.set({ [lastHashKey]: hash }); } catch {}
      showToast('Persona injected');
    }

    async function hydrateFromHive(){
      try {
        chrome.runtime.sendMessage({ type: 'HIVE_PULL_MEMORY' }, async (resp:any)=>{
          if (!resp || !resp.ok) { showToast('Hydrate failed'); return; }
          const msgs: Array<{ role:'user'|'assistant', content:string }> = Array.isArray(resp.messages) ? resp.messages : [];
          const last = msgs.slice(-6);
          const lines = last.map(m=> `${m.role==='user'?'User':'Assistant'}: ${String(m.content||'').replace(/\s+/g,' ').slice(0,200)}`);
          const preface = `SYSTEM: Recent context\n${lines.join('\n')}`.trim();
          const lastHashKey = keyFor('hive_last_context_hash');
          const hash = await hashText(preface);
          let skip = false;
          try {
            const mem: any = await new Promise((res)=> chrome.storage.local.get([lastHashKey], (i)=> res(i)));
            const prev = mem && mem[lastHashKey];
            const wPrev = (window as any).__hiveLastContextHash;
            if (prev && prev === hash) skip = true;
            if (wPrev && wPrev === hash) skip = true;
          } catch {}
          if (skip) { showToast('Already hydrated'); return; }
          const cur = getText();
          setText(`${preface}\n\n${cur}`.trim());
          try { (window as any).__hiveLastContextHash = hash; chrome.storage.local.set({ [lastHashKey]: hash }); } catch {}
          showToast('Hydrated');
        });
      } catch {}
    }

    async function sharePersona(){
      try {
        const origin = (window.location.origin && window.location.origin !== 'null') ? window.location.origin : 'file://';
        const signed = await new Promise<any>((res)=> chrome.storage.local.get(['hive_signed_persona'], (i)=> res(i['hive_signed_persona'])));
        if (!signed || !signed.snapshot || !signed.sig) { promptInjectPersona(null); return; }
        const endpoint = origin + '/hive/receivePersona';
        const resp = await fetch(endpoint, { method:'POST', headers: { 'Content-Type':'application/json' }, body: JSON.stringify({ snapshot: signed.snapshot, signature: signed.sig?.sig || signed.sig }) });
        if (resp.ok) { showToast('Persona shared'); return; }
        // Fallback: prompt injection
        promptInjectPersona(signed.snapshot);
      } catch {
        // Fallback: prompt injection
        try {
          const signed = await new Promise<any>((res)=> chrome.storage.local.get(['hive_signed_persona'], (i)=> res(i['hive_signed_persona'])));
          promptInjectPersona(signed?.snapshot);
        } catch {}
      }
    }

    function sendAttempt(){
      if (!targetEl) return;
      try {
        // Minimal page capture: record user send with current text if enabled
        const text = getText();
        chrome.storage.local.get(['hive_capture_page'], (i:any)=>{
          if (i && i['hive_capture_page'] && text && text.trim()){
            const raw = window.location.origin as string | undefined; const origin = raw && raw !== 'null' ? raw : 'file://';
            try { chrome.runtime.sendMessage({ type:'HIVE_RECORD_MEMORY', payload: { origin, event: { source:'page', role:'user', type:'page_send', text } } }); } catch {}
          }
        });
      } catch {}
      // 1) If inside a form, submit
      const form = (targetEl as HTMLElement).closest('form');
      if (form) { (form as HTMLFormElement).requestSubmit ? (form as HTMLFormElement).requestSubmit() : (form as HTMLFormElement).submit(); return; }
      // 2) Try Enter key
      try {
        const ev = new KeyboardEvent('keydown', { key:'Enter', code:'Enter', bubbles:true });
        (targetEl as any).dispatchEvent(ev);
      } catch {}
      // 3) Try clicking a nearby submit/send button
      const btn = (targetEl.parentElement && targetEl.parentElement.querySelector('button[type="submit"],button[data-testid*="send"],button[aria-label*="Send" i]')) as HTMLButtonElement | null;
      if (btn) btn.click();
    }

    function requestSession(){
      return new Promise<void>((resolve)=>{
        const sessionId = 'hive_' + Math.random().toString(36).slice(2,10);
        const appOrigin = window.location.origin && window.location.origin !== 'null' ? window.location.origin : 'file://';
        // Show waiting message so it doesn't look like it vanished
        try { panel.innerHTML = '<div class="hive-mini">Waiting for approval in Hive popup…</div>'; panel.style.display='block'; if (targetEl) positionNear(targetEl, panel); showToast('Open the Hive popup to approve'); } catch {}
        const payload = { sessionId, requestedScopes: ['persona.use'], requestedPersona: 'default', appOrigin, createdAt: Date.now() };
        // Main request via background
        chrome.runtime.sendMessage({ type: 'HIVE_SESSION_REQUEST', payload }, ()=>{
          resolve();
        });
        // Nudge popup directly so approval banner renders even if forward arrives late
        try { chrome.runtime.sendMessage({ type: 'SHOW_SESSION_REQUEST', payload }); } catch {}
      });
    }

    chrome.runtime.onMessage.addListener((m:any)=>{
      if (m?.type === 'HIVE_SESSION_APPROVED') {
        sessionToken = m.payload?.token;
        (window as any).__hiveSessionToken = sessionToken;
        try { showToast('Session approved'); } catch {}
        try { panel.innerHTML=''; panel.style.display='none'; } catch {}
        // Do not auto-run suggestions to avoid accidental loops
      }
      if (m?.type === 'HIVE_INSERT_TEXT') {
        try {
          const text = String(m?.payload?.text || '');
          const send = !!m?.payload?.send;
          // Guard: avoid duplicate insertion if same text already present or repeated within 3s
          const now = Date.now();
          const cur = getText();
          const same = cur && text && cur.trim() === text.trim();
          const lastTs = (window as any).__hiveLastInsertTs || 0;
          if (!same) setText(text);
          if (send) {
            if (!same && now - lastTs > 500) {
              sendAttempt();
            }
          }
          (window as any).__hiveLastInsertTs = now;
          try { showToast(send ? 'Inserted & sent' : 'Inserted'); } catch {}
          try {
            const raw = window.location.origin as string | undefined; const origin = raw && raw !== 'null' ? raw : 'file://';
            if (sessionToken) chrome.runtime.sendMessage({ type: 'HIVE_UPDATE_CONTEXT', payload: { sessionToken, origin, events: [{ type: send ? 'insert_and_send' : 'insert_text', data: { text } }] } });
          } catch {}
        } catch {}
      }
    });

    async function suggest(){
      if (paused) return;
      if (!sessionToken) {
        await requestSession();
        return; // wait for user to approve; user can click again
      }
      const thread = [ { role:'user', content: getText() || 'Help me draft a reply.' } ];
      const raw = window.location.origin as string | undefined; const origin = raw && raw !== 'null' ? raw : 'file://';
      chrome.runtime.sendMessage({ type: 'HIVE_SUGGEST_REPLY', payload: { sessionToken, thread, origin, max_suggestions: 3 } }, (resp:any)=>{
        panel.innerHTML = '';
        panel.style.display='block';
        // Share persona CTA
        const shareWrap = document.createElement('div'); shareWrap.className='hive-actions';
        const shareBtn = document.createElement('button'); shareBtn.className='hive-btn'; shareBtn.textContent='Share persona with site';
        shareBtn.addEventListener('click', ()=>{ sharePersona(); });
        shareWrap.appendChild(shareBtn);
        panel.appendChild(shareWrap);
        if (!resp || !resp.ok || !Array.isArray(resp.suggestions)) { panel.innerHTML = `<div class="hive-mini">No suggestions (${resp?.error||'error'})</div>`; positionNear(targetEl!, panel); return; }
        resp.suggestions.forEach((s:string)=>{
          const div = document.createElement('div'); div.className='hive-sugg';
          const txt = document.createElement('div'); txt.textContent = s;
          const actions = document.createElement('div'); actions.className='hive-actions';
          const ins = document.createElement('button'); ins.className='hive-btn'; ins.textContent='Insert'; ins.addEventListener('click', ()=>{ setText(s); hidePanel(); if (sessionToken){ const raw = window.location.origin as string | undefined; const origin = raw && raw !== 'null' ? raw : 'file://'; chrome.runtime.sendMessage({ type: 'HIVE_UPDATE_CONTEXT', payload: { sessionToken, origin, events: [{ type:'insert_suggestion', data:{ text: s } }] } }, (resp:any)=>{ if (resp && resp.ok) showToast('Context saved'); }); }});
          const insSend = document.createElement('button'); insSend.className='hive-btn'; insSend.textContent='Insert & Send'; insSend.addEventListener('click', ()=>{ setText(s); hidePanel(); sendAttempt(); if (sessionToken){ const raw = window.location.origin as string | undefined; const origin = raw && raw !== 'null' ? raw : 'file://'; chrome.runtime.sendMessage({ type: 'HIVE_UPDATE_CONTEXT', payload: { sessionToken, origin, events: [{ type:'insert_and_send', data:{ text: s } }] } }, (resp:any)=>{ if (resp && resp.ok) showToast('Context saved'); }); }});
          actions.appendChild(ins);
          actions.appendChild(insSend);
          div.appendChild(txt); div.appendChild(actions);
          panel.appendChild(div);
        });
        positionNear(targetEl!, panel);
      });
    }

    btn.addEventListener('click', suggest);
    hydrateBtn.addEventListener('click', (e)=>{ e.stopPropagation(); hydrateFromHive(); });
    document.addEventListener('click', (e)=>{
      if (!panel.contains(e.target as Node) && !bubble.contains(e.target as Node)) hidePanel();
    });

    // Assistant capture (OpenAI) with dedupe and toggle
    let chatObserver: MutationObserver | null = null;
    const seenAssistant = new Set<string>();
    function trimKey(s:string){ return (s||'').replace(/\s+/g,' ').slice(0,200); }
    function remember(key:string){
      seenAssistant.add(key);
      if (seenAssistant.size > 200){
        const it = seenAssistant.values();
        for (let i=0;i<50;i++){ const n = it.next(); if (n.done) break; seenAssistant.delete(n.value); }
      }
    }
    function recordAssistant(text:string){
      const t = (text||'').trim(); if (!t) return;
      const key = trimKey(t);
      if (seenAssistant.has(key)) return; // dedupe
      remember(key);
      try {
        chrome.storage.local.get(['hive_capture_page'], (i:any)=>{
          if (i && i['hive_capture_page']){
            const raw = window.location.origin as string | undefined; const origin = raw && raw !== 'null' ? raw : 'file://';
            try { chrome.runtime.sendMessage({ type:'HIVE_RECORD_MEMORY', payload: { origin, event: { source:'gpt', role:'assistant', type:'page_assistant', text: t } } }); } catch {}
          }
        });
      } catch {}
    }

    function stopAssistantObserver(){ try { if (chatObserver) { chatObserver.disconnect(); chatObserver = null; } } catch {} }
    function startAssistantObserver(){
      stopAssistantObserver();
      const host = location.hostname;
      const isOpenAI = /chatgpt\.com$|openai\.com$/.test(host);
      const isGemini = /gemini\.google\.com$/.test(host);
      const isClaude = /claude\.ai$/.test(host);
      try {
        const root = document.body;
        chatObserver = new MutationObserver((muts)=>{
          for (const m of muts){
            const els = Array.from((m.addedNodes || [])).filter(n=> (n as Element)?.querySelectorAll).map(n=> n as Element);
            for (const el of els){
              if (isOpenAI){
                const msgs = el.querySelectorAll('[data-message-author-role="assistant"], [data-message-author-role="system"]');
                if (msgs && msgs.length){
                  msgs.forEach((node)=>{
                    const block = (node as HTMLElement).querySelector('[data-message-text], .markdown, [data-testid^="conversation-turn-"]') as HTMLElement | null;
                    const text = block ? (block.innerText || block.textContent || '') : ((node as HTMLElement).innerText || (node as HTMLElement).textContent || '');
                    recordAssistant(text);
                  });
                  continue;
                }
              }
              if (isGemini){
                const container = el.closest('[aria-live="polite"], main') || el;
                const items = container.querySelectorAll('[role="listitem"], article, div[aria-label]');
                if (items && items.length){
                  items.forEach((node)=>{
                    const who = ((node as HTMLElement).getAttribute('data-source') || (node as HTMLElement).getAttribute('aria-label') || '').toLowerCase();
                    const isUser = /user|you/.test(who);
                    if (!isUser){
                      const text = (node as HTMLElement).innerText || (node as HTMLElement).textContent || '';
                      recordAssistant(text);
                    }
                  });
                  continue;
                }
              }
              if (isClaude){
                // Heuristic: look for message blocks commonly used in Claude
                const msgs = el.querySelectorAll('[data-testid*="message"], article, section');
                if (msgs && msgs.length){
                  msgs.forEach((node)=>{
                    const label = ((node as HTMLElement).getAttribute('data-testid') || '').toLowerCase();
                    const likelyAssistant = /assistant|ai|model|response/.test(label);
                    const text = (node as HTMLElement).innerText || (node as HTMLElement).textContent || '';
                    if (likelyAssistant || (text && text.length > 0)){
                      // Best-effort: skip very short nodes that look like UI chrome
                      if (text.trim().length > 20) recordAssistant(text);
                    }
                  });
                  continue;
                }
              }
            }
          }
        });
        chatObserver.observe(root, { childList: true, subtree: true });
      } catch {}
    }

    // Start/stop observer based on toggle
    try {
      chrome.storage.local.get(['hive_capture_page'], (i:any)=>{ if (i && i['hive_capture_page']) startAssistantObserver(); });
      chrome.storage.onChanged.addListener((changes:any)=>{ if (changes && changes['hive_capture_page']) { const v = !!changes['hive_capture_page'].newValue; if (v) startAssistantObserver(); else stopAssistantObserver(); } });
    } catch {}
  } catch {}
})();
