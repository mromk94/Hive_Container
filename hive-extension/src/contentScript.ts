// Content script bridge for Hive Container
// Bridges page window.postMessage <-> extension runtime messages

try { if ((window as any).__hiveInjected) { /* already injected */ } else { (window as any).__hiveInjected = true; } } catch {}
try { console.debug('[Hive] content script injected on', location.hostname); } catch {}


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

    if (source === 'HIVE_MOBILE_SYNC' && payload){
      try {
        const lastHash = String(payload?.lastHash || '');
        chrome.runtime.sendMessage({ type:'HIVE_SYNC', payload: { lastHash } }, (resp:any)=>{
          window.postMessage({ source:'HIVE_MOBILE_SYNC_RESULT', payload: resp }, '*');
        });
      } catch {}
    }

    if (source === 'HIVE_MOBILE_PULL'){
      try {
        chrome.runtime.sendMessage({ type:'HIVE_PULL_MEMORY' }, (resp:any)=>{
          window.postMessage({ source:'HIVE_MOBILE_PULL_RESULT', payload: resp }, '*');
        });
      } catch {}
    }

    if (source === 'HIVE_MOBILE_RECORD' && payload){
      try {
        const raw = window.location.origin as string | undefined; const origin = raw && raw !== 'null' ? raw : 'file://';
        chrome.runtime.sendMessage({ type:'HIVE_RECORD_MEMORY', payload: { origin, event: { source:'mobile', role: payload?.role || 'user', type: payload?.type || 'mobile_event', text: String(payload?.text||'') } } }, (resp:any)=>{
          window.postMessage({ source:'HIVE_MOBILE_RECORD_RESULT', payload: resp }, '*');
        });
      } catch {}
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
      try { console.debug('[Hive] scrape request received'); } catch {}
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
        // Hardened Gemini selectors with graceful fallback
        const chat = document.querySelector('main, [role="main"], [aria-live="polite"]') || document.body;
        let items = Array.from(chat.querySelectorAll('[data-message-author-role], [role="listitem"], article, div[aria-label], [data-qa*="message" i], [data-qa*="response" i]')) as HTMLElement[];
        // prefer elements that have some visible text
        items = items.filter(el => ((el.innerText || el.textContent || '').trim()).length > 0);
        let taken = items.slice(-take);
        if (!taken.length) {
          // Fallback to generic blocks in main
          const generic = Array.from((document.querySelector('main')||document.body).querySelectorAll('p,li,article,section')).filter((el:Element)=> ((el as HTMLElement).innerText||'').trim().length>0) as HTMLElement[];
          taken = generic.slice(-take);
        }
        for (const el of taken){
          const whoAttr = (el.getAttribute('data-message-author-role') || el.getAttribute('data-source') || el.getAttribute('aria-label') || '').toLowerCase();
          const role = /user|you/.test(whoAttr) ? 'user' : 'assistant';
          const text = (el.innerText || el.textContent || '').trim();
          push(role, text);
        }
      } else if (/(perplexity\.ai|poe\.com|copilot\.microsoft\.com|mistral\.ai|cohere\.com|character\.ai|you\.com|groq\.com|phind\.com|huggingface\.co)$/.test(host)) {
        const root = document.querySelector('main,[role="main"],article,section,#__next') || document.body;
        const items = Array.from(root.querySelectorAll('[data-message-author],[data-testid*="message"],article,[role="listitem"],.message, .messages div')) as HTMLElement[];
        const last = items.slice(-take);
        for (const el of last){
          const hint = (el.getAttribute('data-message-author') || el.getAttribute('data-testid') || '').toLowerCase();
          const role = /user|you/.test(hint) ? 'user' : 'assistant';
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
  if (msg?.type === 'HIVE_PAGE_SNAPSHOT'){
    try {
      const id = msg?.payload?.id;
      const sel = window.getSelection && window.getSelection();
      const selection = sel ? sel.toString() : '';
      const title = document.title || '';
      const url = location.href;
      const desc = (document.querySelector('meta[name="description"]') as HTMLMetaElement | null)?.content || '';
      const main = document.querySelector('main') || document.body;
      const blocks = Array.from(main.querySelectorAll('h1,h2,h3,p,li,article,section')).slice(-40) as HTMLElement[];
      const texts = blocks.map(b=> (b.innerText || b.textContent || '').trim()).filter(Boolean).slice(-12);
      const payload = { id, ok:true, snapshot: { title, url, description: desc, selection, texts } };
      chrome.runtime.sendMessage({ type:'HIVE_PAGE_SNAPSHOT_RESULT', payload });
    } catch (e) {
      chrome.runtime.sendMessage({ type:'HIVE_PAGE_SNAPSHOT_RESULT', payload: { ok:false, error:String(e), id: msg?.payload?.id } });
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
      .hive-bubble{position:absolute; z-index:2147483646; font-family:system-ui,sans-serif; display:flex; gap:8px; align-items:center; padding:6px; border-radius:999px; border:1px solid rgba(212,175,55,.65); background:rgba(15,15,15,.86); backdrop-filter:saturate(1.2) blur(6px); box-shadow:0 10px 24px rgba(0,0,0,.45)}
      .hive-btn{padding:6px 10px; border-radius:999px; border:1px solid #d4af37; background:linear-gradient(180deg, rgba(212,175,55,.18), rgba(212,175,55,.08)); color:#eee; cursor:pointer; box-shadow:0 4px 10px rgba(212,175,55,.18); font-size:12px; white-space:nowrap}
      .hive-panel{position:absolute; z-index:2147483647; min-width:240px; max-width:360px; background:#0f0f0f; color:#eee; border:1px solid #1b1b1b; border-radius:10px; box-shadow:0 18px 32px rgba(0,0,0,.45); padding:8px}
      .hive-sugg{border:1px solid #1b1b1b; border-radius:8px; padding:8px; margin-top:6px; background:#111;}
      .hive-actions{display:flex; gap:6px; margin-top:6px}
      .hive-mini{font-size:11px; color:#999}
      .hive-banner{position:fixed; right:16px; bottom:16px; z-index:2147483645; background:#0f0f0f; color:#eee; border:1px solid #1b1b1b; border-radius:999px; padding:6px 10px; box-shadow:0 10px 20px rgba(0,0,0,.35); font-family:system-ui,sans-serif; font-size:12px; display:flex; gap:8px; align-items:center}
      .hive-dot{width:8px; height:8px; border-radius:50%; background:#2ecc71;}
      .hive-dot.paused{ background:#e74c3c; }
      .hive-toast{position:fixed; right:16px; bottom:60px; z-index:2147483645; background:#111; color:#eee; border:1px solid #1b1b1b; border-radius:8px; padding:8px 10px; box-shadow:0 10px 20px rgba(0,0,0,.35); font-size:12px; opacity:0; transition:opacity .2s ease}
      .hive-toast.show{opacity:1}
      /* Dock */
      .hive-dock{position:fixed; top:0; right:0; height:100vh; width:0; overflow:hidden; z-index:2147483646; border-left:1px solid #1b1b1b; background:rgba(10,10,10,.98); box-shadow: -18px 0 40px rgba(0,0,0,.55); transition: width .18s ease;}
      .hive-dock.open{ width: var(--hive-dock-w, 420px); }
      .hive-dock-head{height:36px; display:flex; align-items:center; justify-content:space-between; padding:6px 10px; color:#eee; border-bottom:1px solid #1b1b1b; background:linear-gradient(180deg,#121212,#0e0e0e)}
      .hive-dock-iframe{ width:100%; height: calc(100% - 36px); border:0; background:transparent }
      .hive-dock-tab{ position:fixed; top:50%; right:0; transform:translateY(-50%); z-index:2147483646; background:linear-gradient(180deg, rgba(212,175,55,.18), rgba(212,175,55,.08)); color:#eee; border:1px solid #d4af37; border-right:0; padding:6px 8px; border-radius:8px 0 0 8px; cursor:pointer; writing-mode:vertical-rl; text-orientation:mixed; box-shadow:-10px 0 20px rgba(212,175,55,.18)}
      .hive-dock-tab.detected{ box-shadow:-10px 0 24px rgba(46,204,113,.35), 0 0 0 1px rgba(46,204,113,.25) inset; border-color:#2ecc71 }
      .hive-dock-resize{ position:absolute; left:0; top:0; width:6px; height:100%; cursor:ew-resize; }
      /* Tab menu */
      .hive-tab-menu{ position:fixed; right:44px; top:50%; transform:translateY(-50%); z-index:2147483647; background:#0f0f0f; border:1px solid #1b1b1b; border-radius:12px; box-shadow:0 18px 32px rgba(0,0,0,.45); padding:8px; display:none; width:180px }
      .hive-tab-menu.open{ display:block }
      .hive-tab-menu .row{ display:flex; align-items:center; justify-content:space-between; gap:6px; margin-bottom:6px }
      .hive-tab-menu .title{ font-weight:600; color:#d4af37 }
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
    const readBtn = document.createElement('button'); readBtn.className='hive-btn'; readBtn.textContent='Read';
    bubble.appendChild(btn);
    bubble.appendChild(hydrateBtn);
    bubble.appendChild(readBtn);
    document.documentElement.appendChild(bubble);
    // Prevent focus from leaving the editable field when clicking the bubble/button
    bubble.addEventListener('mousedown', (e)=>{ e.preventDefault(); });
    btn.addEventListener('mousedown', (e)=>{ e.preventDefault(); });
    hydrateBtn.addEventListener('mousedown', (e)=>{ e.preventDefault(); });

    const panel = document.createElement('div'); panel.className='hive-panel'; panel.style.display='none';
    panel.innerHTML = '<div class="hive-mini">Suggestions will appear here…</div>';
    document.documentElement.appendChild(panel);

    // Banner (active/paused)
    const banner = document.createElement('div'); banner.className='hive-banner'; banner.style.display='none';
    const dot = document.createElement('div'); dot.className='hive-dot';
    const label = document.createElement('div'); label.textContent = 'Hive: Active';
    const toggle = document.createElement('button'); toggle.className='hive-btn'; toggle.textContent='Pause';
    toggle.addEventListener('click', (e)=>{ e.stopPropagation(); setPausedState(!paused); });
    banner.appendChild(dot); banner.appendChild(label); banner.appendChild(toggle);
    document.documentElement.appendChild(banner);
    // Right-side dock elements
    const dock = document.createElement('div'); dock.className='hive-dock';
    const resize = document.createElement('div'); resize.className='hive-dock-resize'; dock.appendChild(resize);
    const head = document.createElement('div'); head.className='hive-dock-head'; head.innerHTML = '<div style="font-weight:600;color:#d4af37">Hive Panel</div><div style="display:flex;gap:6px"><button id="hive-dock-min" class="hive-btn">Close</button></div>';
    const frame = document.createElement('iframe'); frame.className='hive-dock-iframe'; frame.src = chrome.runtime.getURL('dist/popup.html');
    dock.appendChild(head); dock.appendChild(frame);
    const tabBtn = document.createElement('button'); tabBtn.className='hive-dock-tab'; tabBtn.textContent = 'Hive';
    const tabMenu = document.createElement('div'); tabMenu.className='hive-tab-menu';
    tabMenu.innerHTML = `
      <div class="row"><div class="title">Hive</div><button id="hive-open-panel" class="hive-btn">Open Panel</button></div>
      <div class="row"><button id="hive-action-suggest" class="hive-btn" style="flex:1">Use my Hive</button></div>
      <div class="row"><button id="hive-action-hydrate" class="hive-btn" style="flex:1">Hydrate</button></div>
      <div class="row"><button id="hive-action-read" class="hive-btn" style="flex:1">Read</button></div>
      <div class="row"><button id="hive-action-share" class="hive-btn" style="flex:1">Share persona</button></div>
      <div class="row"><button id="hive-action-toggle" class="hive-btn" style="flex:1">Pause/Resume</button></div>
      <div class="row"><button id="hive-action-rescan" class="hive-btn" style="flex:1">Rescan AI</button></div>
    `;
    document.documentElement.appendChild(dock);
    document.documentElement.appendChild(tabBtn);
    document.documentElement.appendChild(tabMenu);
    function applyDockWidth(px:number){
      const vw = (()=>{ try { return window.innerWidth || 1200; } catch { return 1200; } })();
      const maxByVw = Math.max(320, vw - 40);
      const clamped = Math.max(320, Math.min(Math.min(900, maxByVw), Math.floor(px)));
      dock.style.setProperty('--hive-dock-w', clamped+'px');
    }
    // Load persisted width and open state
    chrome.storage.local.get(['hive_dock_open','hive_dock_width'], (i:any)=>{
      const w = Number(i['hive_dock_width']||420); applyDockWidth(w);
      if (!!i['hive_dock_open']) dock.classList.add('open');
    });
    function openDock(v:boolean){ dock.classList.toggle('open', v); try { chrome.storage.local.set({ hive_dock_open: v }); } catch {} }
    function toggleTabMenu(){ tabMenu.classList.toggle('open'); }
    tabBtn.addEventListener('click', ()=> toggleTabMenu());
    tabBtn.addEventListener('dblclick', ()=> openDock(true));
    tabMenu.querySelector('#hive-open-panel')?.addEventListener('click', ()=>{ openDock(true); tabMenu.classList.remove('open'); });
    tabMenu.querySelector('#hive-action-suggest')?.addEventListener('click', ()=>{ try { suggest(); } catch {}; tabMenu.classList.remove('open'); });
    tabMenu.querySelector('#hive-action-hydrate')?.addEventListener('click', ()=>{ try { hydrateFromHive(); } catch {}; tabMenu.classList.remove('open'); });
    tabMenu.querySelector('#hive-action-read')?.addEventListener('click', ()=>{ try { deepReadAndInject(); } catch {}; tabMenu.classList.remove('open'); });
    tabMenu.querySelector('#hive-action-share')?.addEventListener('click', ()=>{ try { sharePersona(); } catch {}; tabMenu.classList.remove('open'); });
    tabMenu.querySelector('#hive-action-toggle')?.addEventListener('click', ()=>{ try { setPausedState(!paused); } catch {}; tabMenu.classList.remove('open'); });
    tabMenu.querySelector('#hive-action-rescan')?.addEventListener('click', ()=>{ try { detectAI(); } catch {}; tabMenu.classList.remove('open'); });
    head.querySelector('#hive-dock-min')?.addEventListener('click', ()=> openDock(false));
    // Resizer
    resize.addEventListener('mousedown', (e)=>{
      try {
        e.preventDefault();
        const startX = e.clientX;
        const startW = (dock.getBoundingClientRect().width || 420);
        const onMove = (ev:MouseEvent)=>{ const dx = startX - ev.clientX; applyDockWidth(startW + dx); };
        const onUp = ()=>{ window.removeEventListener('mousemove', onMove); window.removeEventListener('mouseup', onUp); try { const w = dock.getBoundingClientRect().width; chrome.storage.local.set({ hive_dock_width: Math.floor(w) }); } catch {} };
        window.addEventListener('mousemove', onMove); window.addEventListener('mouseup', onUp);
      } catch {}
    });
    let aiDetected = false;
    function updateBanner(){
      const suffix = aiDetected ? ' • AI detected' : '';
      if (paused){ dot.classList.add('paused'); label.textContent='Hive: Paused'+suffix; toggle.textContent='Resume'; hideBubble(); hidePanel(); }
      else { dot.classList.remove('paused'); label.textContent='Hive: Active'+suffix; toggle.textContent='Pause'; }
      try { if (aiDetected) tabBtn.classList.add('detected'); else tabBtn.classList.remove('detected'); } catch {}
    }
    function detectAI(){
      try {
        const host = location.hostname.toLowerCase();
        const knownHosts = ['chatgpt.com','openai.com','claude.ai','gemini.google.com','google.com','deepseek.com','perplexity.ai','poe.com','copilot.microsoft.com','bing.com','mistral.ai','cohere.com','character.ai','you.com','groq.com','phind.com','huggingface.co','reka.ai','grok.com','elevenlabs.io','canva.com','meta.ai','github.com','new-frontend-irt9943l2-adolphuslarrygmailcoms-projects.vercel.app'];
        if (knownHosts.some(h=> host===h || host.endsWith('.'+h))) aiDetected = true;
        const marks = [
          'api.openai.com/v1','api.anthropic.com/v1','generativelanguage.googleapis.com',
          'api.mistral.ai','api.cohere.ai','api.perplexity.ai','api.groq.com','/v1/chat/completions','api.elevenlabs.io',
          'OPENAI_API_KEY','ANTHROPIC_API_KEY','GEMINI_API_KEY','GOOGLE_API_KEY','GROQ_API_KEY','MISTRAL_API_KEY','COHERE_API_KEY','HUGGINGFACEHUB_API_TOKEN'
        ];
        // scan scripts
        const scripts = Array.from(document.scripts).slice(0, 20) as HTMLScriptElement[];
        for (const s of scripts){
          const hay = ((s.src||'') + ' ' + (s.textContent||'')).toLowerCase();
          if (marks.some(m=> hay.includes(m.toLowerCase()))){ aiDetected = true; break; }
        }
        // scan meta/link hrefs lightly
        if (!aiDetected){
          const links = Array.from(document.querySelectorAll('link,meta')) as HTMLElement[];
          for (const el of links){
            const hay = ((el.getAttribute('content')||'') + ' ' + (el.getAttribute('href')||'')).toLowerCase();
            if (marks.some(m=> hay.includes(m.toLowerCase()))){ aiDetected = true; break; }
          }
        }
      } catch {}
      updateBanner();
    }
    function hookNetwork(){
      try {
        const patterns = [
          'api.openai.com','api.anthropic.com','generativelanguage.googleapis.com',
          'api.mistral.ai','api.cohere.ai','api.perplexity.ai','api.groq.com','huggingface.co'
        ];
        const hit = (url:string)=>{ try { if (!url) return; const u = String(url).toLowerCase(); if (patterns.some(p=> u.includes(p))) { aiDetected = true; updateBanner(); } } catch {} };
        const ofetch = window.fetch?.bind(window);
        if (ofetch) {
          window.fetch = function(input: RequestInfo | URL, init?: RequestInit){ try { hit(typeof input === 'string' ? input : (input as any)?.toString?.() || ''); } catch {} ; return ofetch(input as any, init as any); } as any;
        }
        const OXHR = (window as any).XMLHttpRequest;
        if (OXHR && OXHR.prototype){
          const open = OXHR.prototype.open;
          const send = OXHR.prototype.send;
          OXHR.prototype.open = function(this: XMLHttpRequest, method:string, url:string){ try { (this as any).__hive_url = url; } catch {}; return open.apply(this, arguments as any); } as any;
          OXHR.prototype.send = function(this: XMLHttpRequest, body?: any){ try { hit((this as any).__hive_url || ''); } catch {}; return send.apply(this, arguments as any); } as any;
        }
      } catch {}
    }
    refreshPaused();
    try { detectAI(); } catch {}
    try { hookNetwork(); } catch {}

    // Toast
    const toast = document.createElement('div'); toast.className='hive-toast'; toast.textContent='Context saved'; document.documentElement.appendChild(toast);
    function showToast(msg:string){ toast.textContent = msg; toast.classList.add('show'); setTimeout(()=> toast.classList.remove('show'), 1200); }

    function isEditable(n: Element | null): n is HTMLElement {
      if (!n) return false;
      const el = n as HTMLElement;
      if (el.tagName === 'TEXTAREA') return true;
      if (el.tagName === 'INPUT') {
        const t = (el as HTMLInputElement).type || 'text';
        return ['text','search','email','url','tel'].includes(t.toLowerCase());
      }
      if (el.isContentEditable) return true;
      const ce = (el as Element).closest('[contenteditable="true"], [role="textbox"]') as HTMLElement | null;
      if (ce && (ce.isContentEditable || ce.getAttribute('role') === 'textbox')) return true;
      return false;
    }

    function resolveEditable(): HTMLElement | null {
      // prefer current focus target or its editable ancestor
      const active = (document.activeElement as HTMLElement | null);
      const fromTarget = (targetEl && document.contains(targetEl)) ? targetEl : null;
      const candidates: HTMLElement[] = [];
      if (fromTarget) candidates.push(fromTarget as HTMLElement);
      if (active) candidates.push(active);
      // Known selectors for popular chat inputs (ChatGPT, Gemini, Claude, etc.)
      const sel = [
        'textarea#prompt-textarea',
        'textarea[data-testid*="prompt" i]',
        'textarea[placeholder*="message" i]',
        'div[contenteditable="true"][role="textbox"]',
        '[contenteditable="true"][data-testid*="composer" i]'
      ].join(',');
      const q = document.querySelector(sel) as HTMLElement | null;
      if (q) candidates.push(q);
      // Expand with nearest editable ancestor
      for (const c of candidates){
        if (!c) continue;
        if (isEditable(c)) return c;
        const ce = (c as Element).closest('[contenteditable="true"], textarea, input, [role="textbox"]') as HTMLElement | null;
        if (ce) return ce;
      }
      return null;
    }

    function positionNear(el: HTMLElement, anchor: HTMLElement){
      const r = el.getBoundingClientRect();
      const vw = window.innerWidth;
      const vh = window.innerHeight;
      const pad = 12;
      const aw = anchor.offsetWidth || 160;
      const ah = anchor.offsetHeight || 36;
      let top = window.scrollY + r.bottom + 8;
      let left = window.scrollX + r.right - aw;
      if (top + ah > window.scrollY + vh - 80) top = window.scrollY + r.top - ah - 8;
      if (left + aw > window.scrollX + vw - pad) left = window.scrollX + vw - aw - pad;
      if (left < window.scrollX + pad) left = window.scrollX + pad;
      anchor.style.top = `${top}px`;
      anchor.style.left = `${left}px`;
      try { avoidOverlap(anchor); } catch {}
    }

    function rectsOverlap(a:DOMRect, b:DOMRect){ return !(a.right < b.left || a.left > b.right || a.bottom < b.top || a.top > b.bottom); }
    function avoidOverlap(anchor:HTMLElement){
      const bRect = banner.getBoundingClientRect();
      const aRect = anchor.getBoundingClientRect();
      const overlap = rectsOverlap(aRect, bRect);
      if (overlap){
        banner.style.right = 'auto';
        banner.style.left = '16px';
      } else {
        banner.style.left = '';
        banner.style.right = '16px';
      }
    }

    const compactUI = true;
    function showBubble(el: HTMLElement){
      if (compactUI) return;
      if (paused) return;
      targetEl = el;
      bubble.style.display='block';
      positionNear(el, bubble);
    }
    function hideBubble(){ bubble.style.display='none'; }
    function hidePanel(){ panel.style.display='none'; }

    let lastFocusHydrateTs = 0;
    document.addEventListener('focusin', (e)=>{
      const t = e.target as Element | null;
      if (isEditable(t)) {
        showBubble(t as HTMLElement);
        try {
          chrome.storage.local.get(['hive_auto_hydrate_focus','hive_last_state_hash'], (i:any)=>{
            const auto = !!i['hive_auto_hydrate_focus'];
            if (!auto) return;
            const now = Date.now();
            if (now - lastFocusHydrateTs < 2000) return;
            lastFocusHydrateTs = now;
            const lastHash = (i && i['hive_last_state_hash']) ? String(i['hive_last_state_hash']) : '';
            chrome.runtime.sendMessage({ type:'HIVE_SYNC', payload: { lastHash } }, (resp:any)=>{
              if (resp && resp.ok && resp.changed){
                hydrateFromHive();
              }
            });
          });
        } catch {}
      } else { hideBubble(); hidePanel(); }
    });
    document.addEventListener('scroll', ()=>{ if (targetEl) positionNear(targetEl, bubble); if (panel.style.display!=='none' && targetEl) positionNear(targetEl, panel); }, true);
    window.addEventListener('resize', ()=>{ if (targetEl) { positionNear(targetEl, bubble); positionNear(targetEl, panel); } else { try { avoidOverlap(bubble); } catch {} } });

    function getText(): string {
      const el = resolveEditable();
      if (!el) return '';
      if ((el as HTMLInputElement).value != null) return (el as HTMLInputElement).value;
      if (el.isContentEditable) return (el.textContent || '').replace(/\u200B/g,'');
      return '';
    }
    function setText(v: string){
      const el = resolveEditable();
      if (!el) return;
      try { el.focus(); } catch {}
      if ((el as HTMLInputElement).value != null) {
        (el as HTMLInputElement).value = v;
        (el as any).dispatchEvent(new Event('input',{bubbles:true}));
        (el as any).dispatchEvent(new Event('change',{bubbles:true}));
        return;
      }
      if (el.isContentEditable) {
        try {
          // Use execCommand for broader compatibility with React editors
          const sel = window.getSelection && window.getSelection();
          if (sel) { try { sel.removeAllRanges(); } catch {} }
          document.execCommand('selectAll', false, undefined);
          document.execCommand('insertText', false, v);
        } catch {
          el.textContent = v;
        }
        try { (el as any).dispatchEvent(new InputEvent('input',{bubbles:true,data:v} as any)); } catch { (el as any).dispatchEvent(new Event('input',{bubbles:true})); }
        return;
      }
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
      const el = resolveEditable();
      if (!el) return;
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
      const form = (el as HTMLElement).closest('form');
      if (form) { (form as HTMLFormElement).requestSubmit ? (form as HTMLFormElement).requestSubmit() : (form as HTMLFormElement).submit(); return; }
      // 2) Try Enter key
      try {
        const ev = new KeyboardEvent('keydown', { key:'Enter', code:'Enter', bubbles:true });
        (el as any).dispatchEvent(ev);
      } catch {}
      // 3) Try clicking a nearby submit/send button
      let btn = (el.parentElement && el.parentElement.querySelector('button[type="submit"],button[data-testid*="send" i],button[aria-label*="Send" i]')) as HTMLButtonElement | null;
      if (!btn) btn = document.querySelector('button[data-testid*="send" i],button[aria-label*="Send" i],form button[type="submit"]') as HTMLButtonElement | null;
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

    function collectSnapshotText(maxChars=600, includeImages=false): string {
      try {
        const title = document.title || '';
        const sel = window.getSelection && window.getSelection();
        const selection = sel ? (sel.toString() || '') : '';
        const main = document.querySelector('main') || document.body;
        const blocks = Array.from(main.querySelectorAll('h1,h2,h3,p,li,article,section')).slice(-50) as HTMLElement[];
        const texts = blocks.map(b=> (b.innerText || b.textContent || '').trim()).filter(Boolean).slice(-15);
        const joined = texts.join(' \n ').replace(/\s+/g,' ').slice(0, maxChars);
        let imgPart = '';
        if (includeImages){
          const imgs = Array.from((main as HTMLElement).querySelectorAll('figure, img')) as HTMLElement[];
          const items: string[] = [];
          for (const el of imgs.slice(0, 8)){
            if (el.tagName.toLowerCase() === 'figure'){
              const img = el.querySelector('img') as HTMLImageElement | null;
              const cap = el.querySelector('figcaption') as HTMLElement | null;
              const alt = (img?.alt || '').trim();
              const capText = (cap?.innerText || cap?.textContent || '').trim();
              const src = img?.currentSrc || img?.src || '';
              const desc = [alt && `alt:${alt}`, capText && `cap:${capText}`, src && `src:${src}`].filter(Boolean).join(' • ');
              if (desc) items.push(desc.slice(0,220));
            } else if (el.tagName.toLowerCase() === 'img'){
              const img = el as HTMLImageElement;
              const alt = (img.alt || '').trim();
              const src = img.currentSrc || img.src || '';
              const desc = [alt && `alt:${alt}`, src && `src:${src}`].filter(Boolean).join(' • ');
              if (desc) items.push(desc.slice(0,220));
            }
          }
          if (items.length) imgPart = ` Images: ${items.join(' | ')}`;
        }
        const url = location.href;
        const parts = [] as string[];
        if (title) parts.push(`Title: ${title}`);
        if (selection) parts.push(`Selection: ${selection.slice(0,200)}`);
        if (joined) parts.push(`Summary: ${joined}`);
        if (imgPart) parts.push(imgPart);
        parts.push(`URL: ${url}`);
        return parts.join(' | ');
      } catch { return ''; }
    }

    async function suggest(){
      if (paused) return;
      if (!sessionToken) {
        await requestSession();
        return; // wait for user to approve; user can click again
      }
      const thread: Array<{ role:'user'|'assistant'|'system', content:string }> = [ { role:'user', content: getText() || 'Help me draft a reply.' } ];
      try {
        chrome.storage.local.get(['hive_allow_page_read'], (i:any)=>{
          const allowed = !!i['hive_allow_page_read'];
          if (allowed){
            const snap = collectSnapshotText(900, true);
            if (snap) thread.unshift({ role:'system', content: `SYSTEM: Page snapshot -> ${snap}` });
          }
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
        });
        return; // early return to avoid duplicate send below
      } catch {}
    }

    async function deepReadAndInject(){
      try {
        const store:any = await new Promise((res)=> chrome.storage.local.get(['hive_allow_page_read'], (i)=> res(i)));
        const allowed = !!store['hive_allow_page_read'];
        if (!allowed){ showToast('Enable "Allow page reading" in popup'); return; }
        const preface = `SYSTEM: Deep Page Context -> ${collectSnapshotText(1400, true)}`.trim();
        const lastHashKey = keyFor('hive_last_page_read_hash');
        const hash = await hashText(preface);
        let skip = false;
        try {
          const mem: any = await new Promise((res)=> chrome.storage.local.get([lastHashKey], (i)=> res(i)));
          const prev = mem && mem[lastHashKey];
          const wPrev = (window as any).__hiveLastPageReadHash;
          if (prev && prev === hash) skip = true;
          if (wPrev && wPrev === hash) skip = true;
        } catch {}
        if (skip) { showToast('Already read'); return; }
        const cur = getText();
        setText(`${preface}\n\n${cur}`.trim());
        try { (window as any).__hiveLastPageReadHash = hash; chrome.storage.local.set({ [lastHashKey]: hash }); } catch {}
        showToast('Read page context injected');
        try {
          const raw = window.location.origin as string | undefined; const origin = raw && raw !== 'null' ? raw : 'file://';
          chrome.runtime.sendMessage({ type:'HIVE_RECORD_MEMORY', payload: { origin, event: { source:'page', type:'page_read', data: { url: location.href } } } });
        } catch {}
      } catch {}
    }

    btn.addEventListener('click', suggest);
    hydrateBtn.addEventListener('click', (e)=>{ e.stopPropagation(); hydrateFromHive(); });
    readBtn.addEventListener('click', async (e)=>{ e.stopPropagation(); await deepReadAndInject(); });
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
