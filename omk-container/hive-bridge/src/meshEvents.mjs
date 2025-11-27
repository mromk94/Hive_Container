// Mesh event ingestion for Hive Bridge.
//
// This is a lightweight mock handler that simply logs metadata about
// received mesh events. In a production system this would persist
// events and feed them into threat analytics or cooperative caches.

import { auditLog } from './auditLog.mjs';

export function handleMeshEvent(user, body) {
  const eventType = body?.type || 'unknown';
  const originNodeId = body?.origin_node_id || 'unknown';
  const createdAt = body?.created_at || Date.now();
  const payload = body?.payload || {};

  const fromTwinId = payload?.from_twin_id || null;
  const toTwinId = payload?.to_twin_id || null;
  const twinKind = payload?.body?.kind || null;
  const twinUpdatedAt = payload?.body?.updated_at || null;

  auditLog({
    type: 'mesh_event',
    userId: user?.id || 'anonymous',
    eventType,
    originNodeId,
    createdAt,
    fromTwinId,
    toTwinId,
    twinKind,
    twinUpdatedAt,
    ts: Date.now(),
  });

  return { ok: true };
}
