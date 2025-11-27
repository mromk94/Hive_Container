// Prometheus metrics for Hive Bridge.

import client from 'prom-client';

export const register = new client.Registry();

client.collectDefaultMetrics({ register });

export const httpRequestsTotal = new client.Counter({
  name: 'omk_http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'path', 'status'],
});

register.registerMetric(httpRequestsTotal);

export function metricsMiddleware(req, res, next) {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const durationNs = Number(process.hrtime.bigint() - start);
    const path = req.path;
    httpRequestsTotal.labels(req.method, path, String(res.statusCode)).inc();
    // Additional histograms can be added later if needed.
  });
  next();
}
