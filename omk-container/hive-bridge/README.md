# omk-hive-bridge (Mock)

Mock Node.js Hive Bridge service for OMK Container mobile app.

## Endpoints

- `GET /health` — health probe.
- `POST /analyze` — accepts `{ text, context? }` and returns a lightweight risk analysis payload.
- `POST /escalate` — accepts `{ incidentId?, reason?, meta? }` and returns a queued ticket stub.
- `POST /sync-bloom` — accepts `{ lastVersion? }` and returns threat-intel bloom filter metadata.

## Usage

```bash
cd omk-container
npm install
npm --workspace hive-bridge run dev
```

Then call, for example:

```bash
curl -X POST http://localhost:4317/analyze \
  -H 'Content-Type: application/json' \
  -d '{"text":"test prompt with api_key"}'
```
