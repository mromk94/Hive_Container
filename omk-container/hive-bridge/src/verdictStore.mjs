// Central verdict cache backed by Postgres.

import { query } from './db.mjs';

export async function upsertVerdict({
  urlHash,
  host,
  verdict,
  risk,
  source,
  ttlSeconds,
  evidence,
  actions,
}) {
  await query(
    `INSERT INTO verdict_cache (url_hash, host, verdict, risk, source, ttl_seconds, evidence, actions)
     VALUES ($1,$2,$3,$4,$5,$6,$7::jsonb,$8::jsonb)
     ON CONFLICT (url_hash) DO UPDATE SET
       host = EXCLUDED.host,
       verdict = EXCLUDED.verdict,
       risk = EXCLUDED.risk,
       source = EXCLUDED.source,
       ttl_seconds = EXCLUDED.ttl_seconds,
       evidence = EXCLUDED.evidence,
       actions = EXCLUDED.actions,
       updated_at = NOW()`,
    [urlHash, host, verdict, risk, source, ttlSeconds, JSON.stringify(evidence || []), JSON.stringify(actions || [])],
  );
}

export async function getVerdict(urlHash) {
  const res = await query(
    `SELECT url_hash, host, verdict, risk, source, ttl_seconds, evidence, actions
       FROM verdict_cache
      WHERE url_hash = $1
        AND (NOW() - created_at) < (ttl_seconds || ' seconds')::interval`,
    [urlHash],
  );
  return res.rows[0] || null;
}
