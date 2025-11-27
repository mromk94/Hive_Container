// Escalation worker skeleton for Hive Bridge.
//
// Applies quick heuristics, selects an LLM model tier, validates output
// against the JSON schema, and returns a compact result.

import crypto from 'crypto';
import { exampleLlmOutput, validateLlmOutput } from './llmOutputSchema.mjs';

function quickRisk(context) {
  const local = context?.local_decision || {};
  const r = typeof local.risk_score === 'number' ? local.risk_score : 0;
  const bloomHit = Array.isArray(local.path)
    ? local.path.some((p) => String(p).startsWith('bloom_hit'))
    : false;
  let score = r;
  if (bloomHit && score < 0.5) score = 0.5;
  return Math.max(0, Math.min(1, score));
}

function pickModelTier(risk) {
  if (risk < 0.3) return 'S'; // small model
  if (risk < 0.7) return 'M'; // medium
  return 'L'; // large / deep
}

export async function handleEscalation(body) {
  const incidentId = body.incidentId || null;
  const context = body.context || {};
  const risk = quickRisk(context);
  const tier = pickModelTier(risk);

  // TODO: route to real LLM provider based on tier and prompt template.
  const raw = exampleLlmOutput();
  const { ok, errors } = validateLlmOutput(raw);

  const output = ok
    ? raw
    : {
        verdict: 'INSUFFICIENT_DATA',
        confidence: 0,
        summary_1line: 'LLM output invalid or unavailable.',
        evidence: errors || ['Schema validation failed'],
        actions: ['Rely on local classifier and cached verdicts'],
      };

  const ticketId = `OMK-${crypto.randomBytes(4).toString('hex').toUpperCase()}`;

  return {
    ticketId,
    incidentId,
    verdict: output.verdict,
    risk,
    llm: {
      modelTier: tier,
    },
    llm_output: output,
    rate_limited: false,
    retry_after_seconds: 0,
  };
}
