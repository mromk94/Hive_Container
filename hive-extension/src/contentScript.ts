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
    bubble.appendChild(btn);
    document.documentElement.appendChild(bubble);

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

    function sendAttempt(){
      if (!targetEl) return;
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
        chrome.runtime.sendMessage({ type: 'HIVE_SESSION_REQUEST', payload: { sessionId, requestedScopes: ['persona.use'], requestedPersona: 'default', appOrigin, createdAt: Date.now() } }, ()=>{
          resolve();
        });
      });
    }

    chrome.runtime.onMessage.addListener((m:any)=>{
      if (m?.type === 'HIVE_SESSION_APPROVED') { sessionToken = m.payload?.token; (window as any).__hiveSessionToken = sessionToken; }
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
    document.addEventListener('click', (e)=>{
      if (!panel.contains(e.target as Node) && !bubble.contains(e.target as Node)) hidePanel();
    });
  } catch {}
})();
