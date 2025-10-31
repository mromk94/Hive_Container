import type { SessionRequest, ClientSignedToken } from "./types";
import { signStringES256 } from "./crypto";
import { isAllowedOrigin } from "./config";
declare const chrome: any;

const EXT_STORAGE_KEY = "hive_extension_user";
const SESSION_TTL_SECONDS = 60 * 30; // 30 minutes
const USED_TOKEN_KEY = "hive_used_tokens"; // store base64url signatures
const REVOKED_SESSIONS_KEY = "hive_revoked_sessions"; // store sessionIds

async function getStoredUser(): Promise<any | null> {
  return new Promise((res) => chrome.storage.local.get([EXT_STORAGE_KEY], (items: Record<string, any>) => res(items[EXT_STORAGE_KEY] ?? null)));
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

chrome.runtime.onMessage.addListener((msg: any, _sender: any, sendResponse: (resp: any) => void) => {
  if (msg?.type === "HIVE_SESSION_REQUEST") {
    (async () => {
      await new Promise((res) => chrome.storage.local.set({ hive_pending_session: msg.payload as SessionRequest }, () => res(null)));
      chrome.action.openPopup();
      chrome.runtime.sendMessage({ type: "SHOW_SESSION_REQUEST", payload: msg.payload as SessionRequest });
      sendResponse({ ok: true });
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
      sendResponse({ ok: true });
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
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: resp.ok, response: json, status: resp.status });
        } catch (e) {
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: false, error: String(e) });
        }
      }
      // Fallback: echo request
      if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
      sendResponse({ ok: true, response: { echo: true, request: requestPayload } });
    })();
    return true;
  }

  sendResponse({ ok: false, error: "unknown_message" });
});
