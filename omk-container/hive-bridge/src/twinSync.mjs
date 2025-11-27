import { auditLog } from './auditLog.mjs';

export function handleTwinSync(user, body) {
  const snapshot = body?.snapshot;
  if (!snapshot || typeof snapshot !== 'object') {
    return { ok: false, error: 'missing_snapshot' };
  }

  const now = Date.now();
  const twinId = snapshot.twin_id || 'unknown';

  auditLog({
    type: 'twin_sync',
    userId: user?.id || 'anonymous',
    twinId,
    ts: now,
  });

  // Echo back the snapshot with an updated timestamp to simulate a
  // server-side update/ack in this mock.
  const merged = {
    ...snapshot,
    updated_at: now,
  };

  return { ok: true, snapshot: merged };
}
