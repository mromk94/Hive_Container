// Provider registry (MVP)
// Stores active provider and per-provider tokens in chrome.storage.local
// TODO: encrypt tokens at rest in a future iteration

// eslint-disable-next-line @typescript-eslint/no-explicit-any
declare const chrome: any;

export type ProviderId = 'openai' | 'gemini' | 'claude' | 'local';

export type ProviderRegistry = {
  active: ProviderId;
  tokens: Partial<Record<ProviderId, string | undefined>>;
  prefModels?: Partial<Record<ProviderId, string | undefined>>;
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
  const reg = await getRegistry();
  reg.tokens = reg.tokens || {};
  reg.tokens[p] = key || undefined;
  await setRegistry(reg);
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
