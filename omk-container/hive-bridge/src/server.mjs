import express from 'express';
import cors from 'cors';
import morgan from 'morgan';

import { attachAuth } from './auth.mjs';
import { auditLog } from './auditLog.mjs';
import { threatAggregator } from './threatAggregator.mjs';
import { handleEscalation } from './escalationWorker.mjs';
import { handleMemorySync } from './memorySync.mjs';
import { handleTwinSync } from './twinSync.mjs';
import { handleMeshEvent } from './meshEvents.mjs';
import { metricsMiddleware, register } from './metrics.mjs';
import { rateLimiter } from './rateLimiter.mjs';

const app = express();
app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(morgan('dev'));
app.use(metricsMiddleware);
app.use(rateLimiter);
app.use(attachAuth);

const PORT = process.env.PORT || 4317;

app.get('/health', (_req, res) => {
  res.json({ ok: true, service: 'omk-hive-bridge-mock', ts: Date.now() });
});

app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

app.post('/analyze', (req, res) => {
  const { text = '', context = {} } = req.body || {};
  const normalized = String(text).toLowerCase();
  const hasSecrets = /api_key|password|secret|token/.test(normalized);
  const hasViolence = /kill|violence|attack/.test(normalized);

  const riskScore = Number(
    (hasSecrets ? 0.7 : 0) +
      (hasViolence ? 0.5 : 0) +
      Math.min(0.3, (normalized.length || 0) / 2000),
  ).toFixed(2);

  res.json({
    ok: true,
    kind: 'analysis',
    inputBytes: Buffer.byteLength(text),
    riskScore: Number(riskScore),
    tags: [
      ...(hasSecrets ? ['possible_secret_leak'] : []),
      ...(hasViolence ? ['violence_language'] : []),
    ],
    suggestions: [
      'Redact secrets before sending to third parties.',
      'Avoid describing self-harm or violence in operational detail.',
    ],
    context,
  });
});

app.post('/escalate', async (req, res) => {
  const user = req.omkUser;
  const body = req.body || {};

  try {
    const result = await handleEscalation(body);
    auditLog({
      type: 'escalate',
      userId: user?.id || 'anonymous',
      ticketId: result.ticketId,
      incidentId: result.incidentId,
      verdict: result.verdict,
      risk: result.risk,
      ts: Date.now(),
    });
    res.status(202).json({ ok: true, ...result });
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[omk-escalate] error', err);
    res.status(500).json({ ok: false, error: 'escalation_failed' });
  }
});

app.post('/sync-bloom', async (req, res) => {
  const { lastVersion } = req.body || {};
  // In a real service this would run on a schedule or be cached.
  await threatAggregator.refreshFeeds();
  const delta = threatAggregator.buildDelta(lastVersion);
  res.json({ ok: true, ...delta });
});

app.post('/memory-sync', (req, res) => {
  const user = req.omkUser;
  try {
    const result = handleMemorySync(user, req.body || {});
    res.json(result);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[omk-memory-sync] error', err);
    res.status(500).json({ ok: false, error: 'memory_sync_failed' });
  }
});

app.post('/mesh-event', (req, res) => {
  const user = req.omkUser;
  try {
    const result = handleMeshEvent(user, req.body || {});
    res.json(result);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[omk-mesh-event] error', err);
    res.status(500).json({ ok: false, error: 'mesh_event_failed' });
  }
});

app.post('/twin-sync', (req, res) => {
  const user = req.omkUser;
  try {
    const result = handleTwinSync(user, req.body || {});
    res.json(result);
  } catch (err) {
    // eslint-disable-next-line no-console
    console.error('[omk-twin-sync] error', err);
    res.status(500).json({ ok: false, error: 'twin_sync_failed' });
  }
});

app.listen(PORT, () => {
  // eslint-disable-next-line no-console
  console.log(`[omk-hive-bridge] mock server listening on :${PORT}`);
});
