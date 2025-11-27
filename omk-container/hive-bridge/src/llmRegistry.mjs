// Simple registry for LLM models used by llmInteraction.

const models = [];

export function registerModel(model) {
  models.push(model);
}

export function getModelsByKind(kind) {
  return models.filter((m) => m.kind === kind);
}

// Basic picker: prefer lowest costTier that matches kind; fall back to any.
export function pickModelFromRegistry(kind) {
  const byKind = getModelsByKind(kind);
  if (byKind.length === 0) {
    return 'tier-S-generic-model';
  }
  byKind.sort((a, b) => (a.costTier || 1) - (b.costTier || 1));
  return byKind[0].id;
}

// Seed with default entries matching previous behavior.
registerModel({ id: 'tier-M-security-model', kind: 'security', costTier: 2 });
registerModel({ id: 'tier-S-summary-model', kind: 'summary', costTier: 1 });
registerModel({ id: 'tier-M-threat-model', kind: 'threat_intel', costTier: 2 });
registerModel({ id: 'tier-S-remediation-model', kind: 'remediation', costTier: 1 });
registerModel({ id: 'tier-S-generic-model', kind: 'generic', costTier: 1 });
