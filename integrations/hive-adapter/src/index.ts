// Hive Adapter skeleton for LLM vendors
// Drop-in module that exposes a small API for Hive extension to detect presence and route calls.
// This is optional. If installed on a provider site, it enables richer, stable integration.

export type HiveRequest = {
  type: 'chat'|'suggest'|'models';
  payload: any;
};

export type HiveResponse = {
  ok: boolean;
  data?: any;
  error?: string;
};

export function installHiveAdapter() {
  const g: any = window as any;
  if (g.__hiveAdapterInstalled) return;
  g.__hiveAdapterInstalled = true;
  g.addEventListener('message', async (evt: MessageEvent)=>{
    const data = evt?.data || {};
    if (!data || typeof data !== 'object') return;
    if (data.source !== 'HIVE_VENDOR_REQUEST') return;
    const req: HiveRequest = data.payload;
    try {
      const out = await handleHiveRequest(req);
      window.postMessage({ source: 'HIVE_VENDOR_RESPONSE', payload: out }, '*');
    } catch (e) {
      window.postMessage({ source: 'HIVE_VENDOR_RESPONSE', payload: { ok:false, error:String(e) } }, '*');
    }
  });
}

async function handleHiveRequest(req: HiveRequest): Promise<HiveResponse> {
  // Vendors: implement mapping to your internal API here.
  switch (req.type) {
    case 'chat':
      // e.g., POST to your backend, return JSON
      return { ok:false, error:'not_implemented' };
    case 'suggest':
      return { ok:false, error:'not_implemented' };
    case 'models':
      return { ok:false, error:'not_implemented' };
    default:
      return { ok:false, error:'unknown_type' };
  }
}
