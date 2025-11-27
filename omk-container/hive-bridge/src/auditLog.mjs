// Simple console-based audit logger for Hive Bridge.

export function auditLog(event) {
  // In production, write to an append-only log or external system.
  // Keep payloads metadata-only; avoid raw PII.
  // eslint-disable-next-line no-console
  console.log('[omk-audit]', JSON.stringify(event));
}
