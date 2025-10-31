import type { SessionRequest, ClientSignedToken } from "./types";

declare const chrome: any;

const sessionList = document.getElementById("session-list")!;
const userInfo = document.getElementById("user-info")!;
const setSample = document.getElementById("set-sample-user")!;
const saveOpenAI = document.getElementById("save-openai") as HTMLButtonElement | null;
const clearOpenAI = document.getElementById("clear-openai") as HTMLButtonElement | null;
const revokeLast = document.getElementById("revoke-last") as HTMLButtonElement | null;
const openAIInput = document.getElementById("openai-token") as HTMLInputElement | null;

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

saveOpenAI?.addEventListener("click", () => {
  const key = (openAIInput?.value || "").trim();
  chrome.storage.local.get(["hive_extension_user"], (i:any) => {
    const user = i["hive_extension_user"] || { userId: "dev_user", displayName: "Dev User", providerTokens: {} };
    user.providerTokens = user.providerTokens || {};
    user.providerTokens.openai = key || undefined;
    chrome.storage.local.set({ hive_extension_user: user }, () => {
      alert(key ? "OpenAI key saved" : "OpenAI key cleared");
      renderUser();
    });
  });
});

clearOpenAI?.addEventListener("click", () => {
  if (openAIInput) openAIInput.value = "";
  chrome.storage.local.get(["hive_extension_user"], (i:any) => {
    const user = i["hive_extension_user"];
    if (!user) return alert("No user to update. Use dev button first.");
    if (user.providerTokens) delete user.providerTokens.openai;
    chrome.storage.local.set({ hive_extension_user: user }, () => alert("OpenAI key cleared"));
  });
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

renderUser();
renderSession();
