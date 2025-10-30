// WebCrypto utilities for ES256 signing
// Stores/export/imports JWK in chrome.storage.local (extractable for MVP)

// eslint-disable-next-line @typescript-eslint/no-explicit-any
declare const chrome: any;

const PRIV_KEY_STORAGE = "hive_crypto_priv_jwk";
const PUB_KEY_STORAGE = "hive_crypto_pub_jwk";

export type ES256Signature = { alg: "ES256"; sig: string };

function bufferToBase64url(buf: ArrayBuffer): string {
  const bytes = new Uint8Array(buf);
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) binary += String.fromCharCode(bytes[i]);
  const base64 = btoa(binary);
  return base64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

async function getFromStorage<T = unknown>(key: string): Promise<T | null> {
  return new Promise((res) => chrome.storage.local.get([key], (i: Record<string, T>) => res((i && (i as any)[key]) || null)));
}

async function setInStorage(obj: Record<string, unknown>): Promise<void> {
  return new Promise((res) => chrome.storage.local.set(obj, () => res()));
}

export async function getOrCreateES256(): Promise<CryptoKeyPair> {
  const privJwk = await getFromStorage<JsonWebKey>(PRIV_KEY_STORAGE);
  const pubJwk = await getFromStorage<JsonWebKey>(PUB_KEY_STORAGE);

  if (privJwk && pubJwk) {
    const privateKey = await crypto.subtle.importKey(
      "jwk",
      privJwk,
      { name: "ECDSA", namedCurve: "P-256" },
      true,
      ["sign"]
    );
    const publicKey = await crypto.subtle.importKey(
      "jwk",
      pubJwk,
      { name: "ECDSA", namedCurve: "P-256" },
      true,
      ["verify"]
    );
    return { privateKey, publicKey };
  }

  const keyPair = await crypto.subtle.generateKey(
    { name: "ECDSA", namedCurve: "P-256" },
    true, // extractable for MVP; move to OS keystore later
    ["sign", "verify"]
  );
  const exportedPriv = await crypto.subtle.exportKey("jwk", keyPair.privateKey);
  const exportedPub = await crypto.subtle.exportKey("jwk", keyPair.publicKey);
  await setInStorage({ [PRIV_KEY_STORAGE]: exportedPriv, [PUB_KEY_STORAGE]: exportedPub });
  return keyPair;
}

export async function signStringES256(data: string): Promise<ES256Signature> {
  const kp = await getOrCreateES256();
  const enc = new TextEncoder();
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    kp.privateKey,
    enc.encode(data)
  );
  return { alg: "ES256", sig: bufferToBase64url(signature) };
}
