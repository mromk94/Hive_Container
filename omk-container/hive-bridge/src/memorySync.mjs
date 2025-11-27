// Backend handler logic for memory sync.
//
// In a production environment this would persist entries into a
// cloud-backed memory store or data warehouse. Here we log metadata
// only for transparency and debugging.

import { auditLog } from './auditLog.mjs';

export function handleMemorySync(user, body) {
  const since = body?.since ?? 0;
  const entries = Array.isArray(body?.entries) ? body.entries : [];

  const received = entries.length;
  const ts = Date.now();

  auditLog({
    type: 'memory_sync',
    userId: user?.id || 'anonymous',
    since,
    received,
    ts,
  });

  // TODO: persist entries into a durable store (e.g., Postgres, BigQuery).

  return {
    ok: true,
    received,
    lastSynced: ts,
  };
}
