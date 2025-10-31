import type { SessionRequest, ClientSignedToken } from "./types";
import { signStringES256 } from "./crypto";
import { isAllowedOrigin } from "./config";
import { getRegistry } from "./registry";
declare const chrome: any;

const EXT_STORAGE_KEY = "hive_extension_user";
const SESSION_TTL_SECONDS = 60 * 30; // 30 minutes
const USED_TOKEN_KEY = "hive_used_tokens"; // store base64url signatures
const REVOKED_SESSIONS_KEY = "hive_revoked_sessions"; // store sessionIds
const BUILD_INFO = "hive-ext build: 2025-10-31 gemini-v1 latest + registry";

async function getStoredUser(): Promise<any | null> {
  return new Promise((res) => chrome.storage.local.get([EXT_STORAGE_KEY], (items: Record<string, any>) => res(items[EXT_STORAGE_KEY] ?? null)));
}

function mapOpenAIToClaudeBody(req: any): { model: string; messages: any[]; max_tokens: number } {
  let model: string = typeof req?.model === "string" && req.model.startsWith("claude") ? req.model : "claude-3-5-sonnet-latest";
  const messages: any[] = Array.isArray(req?.messages) ? req.messages : [];
  const mapped = messages.map((m) => ({ role: m.role === "assistant" ? "assistant" : "user", content: toStringContent(m.content) }));
  return { model, messages: mapped, max_tokens: 1024 };
}

function toStringContent(content: any): string {
  if (!content) return "";
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content.map((c) => (typeof c === "string" ? c : c?.text || "")).join("\n");
  }
  if (typeof content === "object" && content.text) return content.text;
  try { return JSON.stringify(content); } catch { return String(content); }
}

function mapOpenAIToGeminiBody(req: any): { model: string; contents: any[] } {
  let model: string = typeof req?.model === "string" && req.model.startsWith("gemini") ? req.model : "gemini-1.5-flash-latest";
  if (model === "gemini-1.5-flash") model = "gemini-1.5-flash-latest";
  if (model === "gemini-1.5-pro") model = "gemini-1.5-pro-latest";
  const messages: any[] = Array.isArray(req?.messages) ? req.messages : [];
  const contents = messages.map((m) => ({
    role: m.role === "assistant" ? "model" : "user",
    parts: [{ text: toStringContent(m.content) }],
  }));
  return { model, contents };
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
      try { chrome.runtime.sendMessage({ type: "SHOW_SESSION_REQUEST", payload: msg.payload as SessionRequest }); } catch {}
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
      // Provider routing via registry (fallback to echo)
      const reg = await getRegistry();
      const active = reg.active;
      const key = reg.tokens?.[active];

      if (active === "openai" && key && requestPayload) {
        try {
          const resp = await fetch("https://api.openai.com/v1/chat/completions", {
            method: "POST",
            headers: {
              "Authorization": `Bearer ${key}`,
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

      if (active === "claude" && key && requestPayload) {
        try {
          const mapped = mapOpenAIToClaudeBody(requestPayload);
          const resp = await fetch("https://api.anthropic.com/v1/messages", {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              "x-api-key": key as string,
              "anthropic-version": "2023-06-01"
            },
            body: JSON.stringify(mapped)
          });
          const json = await resp.json();
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: resp.ok, response: json, status: resp.status });
        } catch (e) {
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: false, error: String(e) });
        }
      }

      if (active === "gemini" && key && requestPayload) {
        try {
          const mapped = mapOpenAIToGeminiBody(requestPayload);
          const urls = [
            `https://generativelanguage.googleapis.com/v1/models/${encodeURIComponent(mapped.model)}:generateContent?key=${encodeURIComponent(key)}`,
            `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(mapped.model)}:generateContent?key=${encodeURIComponent(key)}`,
          ];
          let lastJson: any = null;
          for (const u of urls) {
            const resp = await fetch(u, {
              method: "POST",
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({ contents: mapped.contents })
            });
            const json = await resp.json();
            if (resp.ok || resp.status !== 404) {
              if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
              return sendResponse({ ok: resp.ok, response: json, status: resp.status, usedUrl: u });
            }
            lastJson = json;
          }
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: false, response: lastJson, status: 404 });
        } catch (e) {
          if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
          return sendResponse({ ok: false, error: String(e) });
        }
      }

      // Not implemented providers or missing key → echo
      if (sessionToken.singleUse) await markTokenUsed(sessionToken.signature);
      sendResponse({ ok: true, response: { echo: true, provider: active, request: requestPayload } });
    })();
    return true;
  }

  sendResponse({ ok: false, error: "unknown_message" });
});
