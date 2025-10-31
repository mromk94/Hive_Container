// Provider registry (MVP)
// Stores active provider and per-provider tokens in chrome.storage.local
// TODO: encrypt tokens at rest in a future iteration

// eslint-disable-next-line @typescript-eslint/no-explicit-any
declare const chrome: any;

export type ProviderId = 'openai' | 'gemini' | 'claude' | 'grok' | 'deepseek' | 'local';

export type ProviderRegistry = {
  active: ProviderId;
  tokens: Partial<Record<ProviderId, string | undefined>>;
  prefModels?: Partial<Record<ProviderId, string | undefined>>;
  useWebSession?: Partial<Record<ProviderId, boolean>>;
};

const REGISTRY_KEY = 'hive_provider_registry';

export async function getRegistry(): Promise<ProviderRegistry> {
  return new Promise((res) =>
    chrome.storage.local.get([REGISTRY_KEY], (i: Record<string, any>) => {
      const def: ProviderRegistry = { active: 'openai', tokens: {} };
      res((i && i[REGISTRY_KEY]) || def);
    })
  );
}

export async function setRegistry(reg: ProviderRegistry): Promise<void> {
  return new Promise((res) => chrome.storage.local.set({ [REGISTRY_KEY]: reg }, () => res()));
}

export async function setActiveProvider(p: ProviderId): Promise<void> {
  const reg = await getRegistry();
  reg.active = p;
  await setRegistry(reg);
}

export async function setProviderToken(p: ProviderId, key: string | undefined): Promise<void> {
  const enc = await encryptToken(key);
  const obj = await new Promise<Record<string, any>>((res)=>chrome.storage.local.get(['hive_provider_tokens_enc'], (i:any)=>res(i||{})));
  const store = obj['hive_provider_tokens_enc'] || {};
  if (enc) store[p] = enc; else delete store[p];
  await new Promise((res)=>chrome.storage.local.set({ hive_provider_tokens_enc: store }, ()=>res(null)));
}

export async function setPreferredModel(p: ProviderId, model: string | undefined): Promise<void> {
  const reg = await getRegistry();
  reg.prefModels = reg.prefModels || {};
  reg.prefModels[p] = model || undefined;
  await setRegistry(reg);
}

export async function getPreferredModel(p: ProviderId): Promise<string | undefined> {
  const reg = await getRegistry();
  return reg.prefModels?.[p];
}

export async function setUseWebSession(p: ProviderId, enabled: boolean): Promise<void> {
  const reg = await getRegistry();
  reg.useWebSession = reg.useWebSession || {};
  reg.useWebSession[p] = !!enabled;
  await setRegistry(reg);
}

export async function getUseWebSession(p: ProviderId): Promise<boolean> {
  const reg = await getRegistry();
  return !!reg.useWebSession?.[p];
}

const VAULT_KEY = 'hive_vault_key_raw';

async function getOrCreateVaultKey(): Promise<CryptoKey> {
  const raw = await new Promise<string | undefined>((res)=>chrome.storage.local.get([VAULT_KEY], (i:any)=>res(i && i[VAULT_KEY])));
  if (raw) {
    const buf = base64urlToBuffer(raw);
    return crypto.subtle.importKey('raw', buf, { name: 'AES-GCM' }, false, ['encrypt','decrypt']);
  }
  const k = await crypto.subtle.generateKey({ name: 'AES-GCM', length: 256 }, true, ['encrypt','decrypt']);
  const exported = new Uint8Array(await crypto.subtle.exportKey('raw', k));
  await new Promise((res)=>chrome.storage.local.set({ [VAULT_KEY]: bufferToBase64url(exported) }, ()=>res(null)));
  return k;
}

function bufferToBase64url(buf: ArrayBuffer | Uint8Array): string {
  const arr = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
  let b = '';
  for (let i=0;i<arr.length;i++) b += String.fromCharCode(arr[i]);
  return btoa(b).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/g,'');
}

function base64urlToBuffer(s: string): ArrayBuffer {
  const pad = s.length % 4 === 2 ? '==' : s.length % 4 === 3 ? '=' : '';
  const bin = atob(s.replace(/-/g,'+').replace(/_/g,'/') + pad);
  const arr = new Uint8Array(bin.length);
  for (let i=0;i<bin.length;i++) arr[i] = bin.charCodeAt(i);
  return arr.buffer;
}

async function encryptToken(value?: string): Promise<string | undefined> {
  if (!value) return undefined;
  const key = await getOrCreateVaultKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, new TextEncoder().encode(value));
  return bufferToBase64url(iv) + '.' + bufferToBase64url(ct);
}

async function decryptToken(enc?: string): Promise<string | undefined> {
  if (!enc) return undefined;
  const [ivB64, ctB64] = enc.split('.');
  if (!ivB64 || !ctB64) return undefined;
  const key = await getOrCreateVaultKey();
  const iv = new Uint8Array(base64urlToBuffer(ivB64));
  const pt = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, base64urlToBuffer(ctB64));
  return new TextDecoder().decode(pt);
}

export async function getProviderToken(p: ProviderId): Promise<string | undefined> {
  const obj = await new Promise<Record<string, any>>((res)=>chrome.storage.local.get(['hive_provider_tokens_enc'], (i:any)=>res(i||{})));
  const store = obj['hive_provider_tokens_enc'] || {};
  const enc = store[p];
  return decryptToken(enc);
}

// Persona Profile (encrypted at rest)
export type PersonaProfile = {
  name: string;
  tone: { formality: number; concision: number };
  keywords: string; // comma-separated
  bio: string;
  rules: string; // do/don't and preferences
};

const PERSONA_KEY = 'hive_persona_profile_enc';

function defaultPersona(): PersonaProfile {
  return {
    name: 'My Hive',
    tone: { formality: 50, concision: 50 },
    keywords: '',
    bio: '',
    rules: ''
  };
}

export async function getPersonaProfile(): Promise<PersonaProfile> {
  const obj = await new Promise<Record<string, any>>((res)=>chrome.storage.local.get([PERSONA_KEY], (i:any)=>res(i||{})));
  const enc = obj[PERSONA_KEY];
  if (!enc) return defaultPersona();
  try {
    const json = await decryptToken(enc);
    const parsed = json ? JSON.parse(json) : null;
    if (!parsed) return defaultPersona();
    // basic shape validation
    return {
      name: typeof parsed.name === 'string' ? parsed.name : 'My Hive',
      tone: {
        formality: Math.max(0, Math.min(100, Number(parsed?.tone?.formality ?? 50))),
        concision: Math.max(0, Math.min(100, Number(parsed?.tone?.concision ?? 50)))
      },
      keywords: typeof parsed.keywords === 'string' ? parsed.keywords : '',
      bio: typeof parsed.bio === 'string' ? parsed.bio : '',
      rules: typeof parsed.rules === 'string' ? parsed.rules : ''
    };
  } catch {
    return defaultPersona();
  }
}

export async function setPersonaProfile(p: PersonaProfile | undefined): Promise<void> {
  if (!p) {
    await new Promise((res)=>chrome.storage.local.remove([PERSONA_KEY], ()=>res(null)));
    return;
  }
  const serialized = JSON.stringify(p);
  const enc = await encryptToken(serialized);
  await new Promise((res)=>chrome.storage.local.set({ [PERSONA_KEY]: enc }, ()=>res(null)));
}

// Deep User Profile (encrypted at rest)
export type UserProfile = {
  personality: string; // free-form traits/description
  allergies: string;   // medical: allergies (user-provided)
  preferences: string; // general preferences
  location: string;    // city/region (optional)
  interests: string;   // comma-separated interests
  education: string;   // education background
  socials: string;     // social handles, comma-separated or lines
};

const USER_PROFILE_KEY = 'hive_user_profile_enc';

function defaultUserProfile(): UserProfile {
  return { personality: '', allergies: '', preferences: '', location: '', interests: '', education: '', socials: '' };
}

export async function getUserProfile(): Promise<UserProfile> {
  const obj = await new Promise<Record<string, any>>((res)=>chrome.storage.local.get([USER_PROFILE_KEY], (i:any)=>res(i||{})));
  const enc = obj[USER_PROFILE_KEY];
  if (!enc) return defaultUserProfile();
  try {
    const json = await decryptToken(enc);
    const parsed = json ? JSON.parse(json) : null;
    if (!parsed) return defaultUserProfile();
    return {
      personality: typeof parsed.personality === 'string' ? parsed.personality : '',
      allergies: typeof parsed.allergies === 'string' ? parsed.allergies : '',
      preferences: typeof parsed.preferences === 'string' ? parsed.preferences : '',
      location: typeof parsed.location === 'string' ? parsed.location : '',
      interests: typeof parsed.interests === 'string' ? parsed.interests : '',
      education: typeof parsed.education === 'string' ? parsed.education : '',
      socials: typeof parsed.socials === 'string' ? parsed.socials : ''
    };
  } catch { return defaultUserProfile(); }
}

export async function setUserProfile(p: UserProfile | undefined): Promise<void> {
  if (!p) {
    await new Promise((res)=>chrome.storage.local.remove([USER_PROFILE_KEY], ()=>res(null)));
    return;
  }
  const enc = await encryptToken(JSON.stringify(p));
  await new Promise((res)=>chrome.storage.local.set({ [USER_PROFILE_KEY]: enc }, ()=>res(null)));
}

// Per-domain consent logs
export type ConsentEntry = { domain: string; scopes: string[]; ts: number };
const CONSENT_KEY = 'hive_consent_logs';

export async function getConsentLogs(): Promise<ConsentEntry[]> {
  const obj = await new Promise<Record<string, any>>((res)=>chrome.storage.local.get([CONSENT_KEY], (i:any)=>res(i||{})));
  const arr: ConsentEntry[] = Array.isArray(obj[CONSENT_KEY]) ? obj[CONSENT_KEY] : [];
  return arr.filter(e=>typeof e?.domain==='string' && Array.isArray(e?.scopes) && typeof e?.ts==='number');
}

export async function addConsent(domain: string, scopes: string[]): Promise<void> {
  const cur = await getConsentLogs();
  const i = cur.findIndex(e=>e.domain===domain);
  const set = new Set((i>=0 ? cur[i].scopes : []).concat(scopes || []));
  const entry: ConsentEntry = { domain, scopes: Array.from(set), ts: Date.now() };
  if (i>=0) cur[i] = entry; else cur.push(entry);
  await new Promise((res)=>chrome.storage.local.set({ [CONSENT_KEY]: cur }, ()=>res(null)));
}

export async function removeConsent(domain: string): Promise<void> {
  const cur = await getConsentLogs();
  const next = cur.filter(e=>e.domain!==domain);
  await new Promise((res)=>chrome.storage.local.set({ [CONSENT_KEY]: next }, ()=>res(null)));
}
