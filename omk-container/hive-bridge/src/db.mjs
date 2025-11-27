// Simple Postgres connector for Hive Bridge backend infra.
// Uses environment variables: PGHOST, PGPORT, PGUSER, PGPASSWORD, PGDATABASE.

import pg from 'pg';

const { Pool } = pg;

export const pool = new Pool({
  host: process.env.PGHOST || 'localhost',
  port: Number(process.env.PGPORT || 5432),
  user: process.env.PGUSER || 'omk',
  password: process.env.PGPASSWORD || 'omk',
  database: process.env.PGDATABASE || 'omk_hive',
  max: 10,
});

export async function query(text, params) {
  const client = await pool.connect();
  try {
    const res = await client.query(text, params);
    return res;
  } finally {
    client.release();
  }
}
