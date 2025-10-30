import type { SessionRequest, ClientSignedToken } from "./types";
declare const chrome: any;

const EXT_STORAGE_KEY = "hive_extension_user";
const SESSION_TTL_SECONDS = 60 * 30; // 30 minutes

async function getStoredUser(): Promise<any | null> {
  return new Promise((res) => chrome.storage.local.get([EXT_STORAGE_KEY], (items: Record<string, any>) => res(items[EXT_STORAGE_KEY] ?? null)));
}

async function hashString(s: string): Promise<string> {
  const enc = new TextEncoder();
  const buf = enc.encode(s);
  const hash = await crypto.subtle.digest("SHA-256", buf);
  return Array.from(new Uint8Array(hash)).map((b) => b.toString(16).padStart(2, "0")).join("");
}

async function createClientSignedToken(userId: string, sessionId: string, scopes: string[], origin?: string): Promise<ClientSignedToken> {
  const iat = Math.floor(Date.now() / 1000);
  const exp = iat + SESSION_TTL_SECONDS;
  const payload = `${userId}|${sessionId}|${scopes.join(",")}|${iat}|${exp}|${origin ?? ""}`;
  const signature = btoa(await hashString(payload)); // TODO: replace with WebCrypto signing
  return { sessionId, sub: userId, scopes, exp, iat, signature, origin };
}

chrome.runtime.onMessage.addListener((msg: any, _sender: any, sendResponse: (resp: any) => void) => {
  if (msg?.type === "HIVE_SESSION_REQUEST") {
    chrome.action.openPopup();
    chrome.runtime.sendMessage({ type: "SHOW_SESSION_REQUEST", payload: msg.payload as SessionRequest });
    sendResponse({ ok: true });
    return true;
  }

  if (msg?.type === "HIVE_CREATE_TOKEN") {
    (async () => {
      const { userId, sessionId, scopes, origin } = msg.payload || {};
      if (!userId || !sessionId || !Array.isArray(scopes)) return sendResponse({ ok: false, error: "invalid_args" });
      const token = await createClientSignedToken(userId, sessionId, scopes, origin);
      sendResponse({ ok: true, token });
    })();
    return true;
  }

  if (msg?.type === "APP_FORWARD_REQUEST") {
    (async () => {
      const { sessionToken, requestPayload, origin } = msg.payload || {};
      const user = await getStoredUser();
      if (!user) return sendResponse({ ok: false, error: "no_user" });
      if (!sessionToken || sessionToken.sub !== user.userId) return sendResponse({ ok: false, error: "invalid_token_sub" });
      if (sessionToken.exp < Math.floor(Date.now() / 1000)) return sendResponse({ ok: false, error: "token_expired" });
      if (sessionToken.origin && origin && sessionToken.origin !== origin) return sendResponse({ ok: false, error: "origin_mismatch" });
      const providerKey = user.providerTokens?.["openai"];
      if (providerKey && requestPayload) {
        try {
          const resp = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${providerKey}`,
              "Content-Type": "application/json"
            },
            body: JSON.stringify(requestPayload)
          });
          const json = await resp.json();
          return sendResponse({ ok: resp.ok, response: json, status: resp.status });
        } catch (e) {
          return sendResponse({ ok: false, error: String(e) });
        }
      }
      // Fallback: echo request
      sendResponse({ ok: true, response: { echo: true, request: requestPayload } });
    })();
    return true;
  }

  sendResponse({ ok: false, error: "unknown_message" });
});
