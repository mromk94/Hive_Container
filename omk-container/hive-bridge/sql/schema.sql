-- Postgres schema for Hive Bridge backend infra.

CREATE TABLE IF NOT EXISTS verdict_cache (
  url_hash TEXT PRIMARY KEY,
  host TEXT NOT NULL,
  verdict TEXT NOT NULL,
  risk DOUBLE PRECISION NOT NULL,
  source TEXT NOT NULL,
  ttl_seconds INTEGER NOT NULL DEFAULT 2592000, -- 30 days
  evidence JSONB NOT NULL DEFAULT '[]'::jsonb,
  actions JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS verdict_cache_created_at_idx ON verdict_cache (created_at);
