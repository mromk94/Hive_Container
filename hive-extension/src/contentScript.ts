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
  },
  false
);

chrome.runtime.onMessage.addListener((msg: any) => {
  if (msg?.type === "HIVE_SESSION_APPROVED") {
    window.postMessage({ source: "HIVE_SESSION_APPROVED", payload: msg.payload }, "*");
  }
});
