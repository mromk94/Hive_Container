// Verify ES256-signed persona snapshot using a public JWK (P-256)
// The signature must be base64url over the exact JSON string used by the signer.
// If possible, verify against the raw request body string.

export type VerifyInput = {
  snapshot: any | string; // object or raw JSON string
  signatureB64Url: string; // base64url signature of the JSON string
  publicJwk: JsonWebKey; // EC P-256 public key JWK
};

function getWebCrypto(): Crypto {
  // Browser or Node >=18
  if (typeof globalThis !== 'undefined' && (globalThis as any).crypto && (globalThis as any).crypto.subtle) return (globalThis as any).crypto as Crypto;
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { webcrypto } = require('node:crypto');
    return webcrypto as unknown as Crypto;
  } catch {
    throw new Error('WebCrypto not available');
  }
}

function base64urlToUint8(b64url: string): Uint8Array {
  const pad = b64url.length % 4 === 2 ? '==' : b64url.length % 4 === 3 ? '=' : '';
  const b64 = b64url.replace(/-/g, '+').replace(/_/g, '/') + pad;
  const raw = Buffer.from(b64, 'base64');
  return new Uint8Array(raw.buffer, raw.byteOffset, raw.byteLength);
}

export async function verifySignedPersona({ snapshot, signatureB64Url, publicJwk }: VerifyInput): Promise<boolean> {
  const crypto = getWebCrypto();
  const subtle = crypto.subtle;
  const key = await subtle.importKey(
    'jwk',
    publicJwk,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['verify']
  );
  const enc = new TextEncoder();
  const raw = typeof snapshot === 'string' ? snapshot : JSON.stringify(snapshot);
  const sig = base64urlToUint8(signatureB64Url);
  return subtle.verify({ name: 'ECDSA', hash: 'SHA-256' }, key, sig, enc.encode(raw));
}
