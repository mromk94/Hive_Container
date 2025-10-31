import type { SessionRequest, ClientSignedToken } from "./types";
import type { ProviderId } from "./registry";
import { getRegistry, setActiveProvider, setProviderToken } from "./registry";

declare const chrome: any;

const sessionList = document.getElementById("session-list")!;
const userInfo = document.getElementById("user-info")!;
const setSample = document.getElementById("set-sample-user")!;
const providerSelect = document.getElementById("provider-select") as HTMLSelectElement | null;
const saveTokenBtn = document.getElementById("save-token") as HTMLButtonElement | null;
const clearTokenBtn = document.getElementById("clear-token") as HTMLButtonElement | null;
const revokeLast = document.getElementById("revoke-last") as HTMLButtonElement | null;
const providerTokenInput = document.getElementById("provider-token") as HTMLInputElement | null;
const debugInfoBtn = document.getElementById("debug-info") as HTMLButtonElement | null;

let pendingSession: SessionRequest | null = null;

function renderUser() {
  chrome.storage.local.get(["hive_extension_user"], (items: any) => {
    const user = items["hive_extension_user"];
    if (!user) {
      userInfo.textContent = "No user stored. (Use dev button)";
    } else {
      userInfo.textContent = `${user.displayName ?? user.userId}`;
    }
  });
}

async function initProviderUI() {
  const reg = await getRegistry();
  if (providerSelect) providerSelect.value = reg.active || "openai";
  if (providerTokenInput) providerTokenInput.value = reg.tokens?.[reg.active as ProviderId] || "";
}

chrome.runtime.onMessage.addListener((msg: any) => {
  if (msg?.type === "SHOW_SESSION_REQUEST") {
    pendingSession = msg.payload as SessionRequest;
    renderSession();
  }
});

// Initialize from storage in case popup opened before runtime message arrives
chrome.storage.local.get(["hive_pending_session"], (items: any) => {
  const s = items["hive_pending_session"] as SessionRequest | undefined;
  if (s) {
    pendingSession = s;
    renderSession();
    chrome.storage.local.remove(["hive_pending_session"]);
  }
});

// Initialize provider UI on load
void initProviderUI();

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
});

saveTokenBtn?.addEventListener("click", async () => {
  const active = (providerSelect?.value || "openai") as ProviderId;
  const key = (providerTokenInput?.value || "").trim();
  await setProviderToken(active, key || undefined);
  alert(key ? "Provider key saved" : "Provider key cleared");
});

clearTokenBtn?.addEventListener("click", async () => {
  if (providerTokenInput) providerTokenInput.value = "";
  const active = (providerSelect?.value || "openai") as ProviderId;
  await setProviderToken(active, undefined);
  alert("Provider key cleared");
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
