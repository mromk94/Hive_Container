// Simple validator for LLM escalation outputs.

const VERDICTS = new Set(['ALLOW', 'REVIEW', 'BLOCK', 'INSUFFICIENT_DATA']);

export function validateLlmOutput(obj) {
  const errors = [];
  if (typeof obj !== 'object' || obj === null) {
    errors.push('Output must be a JSON object');
    return { ok: false, errors };
  }

  if (!VERDICTS.has(obj.verdict)) {
    errors.push('Invalid verdict');
  }
  if (typeof obj.confidence !== 'number' || obj.confidence < 0 || obj.confidence > 1) {
    errors.push('confidence must be a number in [0,1]');
  }
  if (typeof obj.summary_1line !== 'string' || obj.summary_1line.length > 240) {
    errors.push('summary_1line must be a short string');
  }
  if (!Array.isArray(obj.evidence)) {
    errors.push('evidence must be an array');
  } else if (obj.evidence.length > 5) {
    errors.push('evidence max length 5');
  }
  if (!Array.isArray(obj.actions)) {
    errors.push('actions must be an array');
  } else if (obj.actions.length > 5) {
    errors.push('actions max length 5');
  }

  return { ok: errors.length === 0, errors };
}

export function exampleLlmOutput() {
  return {
    verdict: 'BLOCK',
    confidence: 0.9,
    summary_1line:
      'Login page hosted on a very new domain with suspicious certificate and text.',
    evidence: [
      'Domain age 2 days with high-risk ASN',
      'TLS cert valid for 30 days',
      'Page text urges immediate credential reset',
    ],
    actions: [
      'Do not enter credentials on this page',
      'Use the official app or bookmarked URL to sign in',
    ],
  };
}
