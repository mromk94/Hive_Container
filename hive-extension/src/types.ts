export type SessionRequest = {
  sessionId: string;
  appOrigin: string;
  requestedScopes: string[];
  requestedPersona?: string;
  nonce?: string;
  createdAt?: number;
};

export type ClientSignedToken = {
  sessionId: string;
  sub: string;
  scopes: string[];
  exp: number;
  iat: number;
  signature: string;
  origin?: string;
};

export {};
