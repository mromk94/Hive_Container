// Simple in-memory rate limiter for dev/staging.
// In production this should be backed by Redis or another shared store.

const BUCKET_WINDOW_MS = 60_000; // 1 minute
const MAX_REQUESTS_PER_WINDOW = 120;

const buckets = new Map(); // key -> { count, resetAt }

export function rateLimiter(req, res, next) {
  const userId = (req.omkUser && req.omkUser.id) || 'anonymous';
  const now = Date.now();
  const key = `${userId}`;
  let bucket = buckets.get(key);
  if (!bucket || bucket.resetAt <= now) {
    bucket = { count: 0, resetAt: now + BUCKET_WINDOW_MS };
    buckets.set(key, bucket);
  }
  bucket.count += 1;
  if (bucket.count > MAX_REQUESTS_PER_WINDOW) {
    res.status(429).json({ ok: false, error: 'rate_limited' });
    return;
  }
  next();
}
