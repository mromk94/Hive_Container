// Minimal auth skeleton for Hive Bridge.
// In production this should be replaced with a real key/JWT store.

export function authenticateRequest(req) {
  const apiKey = req.headers['x-omk-api-key'];
  // TODO: look up apiKey in a key store; for now accept anything in dev.
  const devUser = apiKey ? { id: 'dev-user', apiKey } : { id: 'anonymous' };
  return devUser;
}

export function attachAuth(req, _res, next) {
  req.omkUser = authenticateRequest(req);
  next();
}
