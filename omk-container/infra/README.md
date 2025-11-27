# OMK Hive Bridge Infra Sketch

This directory contains a minimal sketch for backend infra.

- `docker-compose.yml` at repo root can be used to run Postgres and
  Hive Bridge locally.
- `hive-bridge/sql/schema.sql` defines the verdict_cache table.

For a real Terraform-based deployment, you would:

- Provision a managed Postgres instance.
- Deploy the Hive Bridge service (e.g., Cloud Run, ECS, or Kubernetes).
- Wire environment variables (PGHOST, PGPORT, PGUSER, PGPASSWORD,
  PGDATABASE, PORT).
- Expose /health and /metrics for monitoring.
