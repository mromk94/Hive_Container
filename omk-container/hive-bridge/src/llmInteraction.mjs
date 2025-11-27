// LLM interaction layer for Hive Bridge.
//
// This module defines a small in-memory scheduler for LLM tasks with
// priority queues, streaming support (via async generators),
// context-aware prompt assembly, and local fallbacks when offline.

import { validateLlmOutput, exampleLlmOutput } from './llmOutputSchema.mjs';
import { pickModelFromRegistry } from './llmRegistry.mjs';

let nextId = 1;

export class LlmTask {
  constructor({ kind, priority, context, stream }) {
    this.id = `task-${nextId++}`;
    this.kind = kind; // 'security' | 'summary' | 'threat_intel' | 'remediation'
    this.priority = priority;
    this.context = context; // compact snapshot + local signals
    this.stream = stream ?? false;
    this.createdAt = Date.now();
  }
}

const queue = [];

/** Enqueue a task and keep queue sorted by priority (desc) then createdAt. */
export function enqueueTask(options) {
  const task = new LlmTask(options);
  queue.push(task);
  queue.sort((a, b) => {
    if (b.priority !== a.priority) return b.priority - a.priority;
    return a.createdAt - b.createdAt;
  });
  return task;
}

/** Pop the next highest-priority task, or null if empty. */
export function dequeueTask() {
  return queue.shift() ?? null;
}

export function pickModel(task) {
  const kind = task.kind || 'generic';
  return pickModelFromRegistry(kind);
}

/** Build a context-aware prompt for the given task.
 * Injects app name, user action, and compact snapshot metadata.
 */
export function buildPrompt(task) {
  const ctx = task.context || {};
  const appName = ctx.appLabel || ctx.appPackage || 'this app';
  const action = ctx.actionType || task.kind;
  const snapshot = ctx.snapshot || {};

  const baseline = 'You are the Larry-State OMK Container assistant: '
    + 'privacy-first, cache-first, and offline-resilient. Coordinate '
    + 'device, cloud, and local mesh context without leaking '
    + 'unnecessary data. ';

  return {
    system: baseline
      + `You are handling ${task.kind} tasks. `
      + `The current app is ${appName}. The user requested action ${action}. `
      + 'Use only the provided compact snapshot and local signals.',
    user: {
      snapshot,
      local_signals: ctx.localSignals || {},
    },
  };
}

/** Execute a task in non-streaming mode.
 * This is currently a stub that returns exampleLlmOutput() and validates it.
 * In a real build, this would call the chosen provider SDK.
 */
export async function runTaskOnce(task) {
  if (process.env.LLM_OFFLINE === '1') {
    // Local fallback: mark as insufficient data, avoid network.
    return {
      model: 'offline-fallback',
      output: {
        verdict: 'INSUFFICIENT_DATA',
        confidence: 0,
        summary_1line: 'Offline mode: using local protections only.',
        evidence: ['LLM provider disabled or unreachable'],
        actions: ['Rely on on-device classifier and cached verdicts'],
      },
      validation: { ok: true, errors: [] },
    };
  }

  const modelId = pickModel(task);
  const prompt = buildPrompt(task);

  // TODO: call real provider here. For now re-use example output.
  const raw = exampleLlmOutput();
  const { ok, errors } = validateLlmOutput(raw);

  const output = ok
    ? raw
    : {
        verdict: 'INSUFFICIENT_DATA',
        confidence: 0,
        summary_1line: 'LLM output invalid or unavailable.',
        evidence: errors || ['Schema validation failed'],
        actions: ['Use local protections and consider manual review'],
      };

  return {
    model: modelId,
    prompt,
    output,
    validation: { ok, errors },
  };
}

/** Execute a task in streaming mode as an async generator of text chunks.
 * This stub yields 2–3 chunks derived from the final summary_1line.
 */
export async function* runTaskStream(task) {
  const result = await runTaskOnce(task);
  const text = result.output.summary_1line || '';
  if (!text) {
    yield '[no content]';
    return;
  }
  const mid = Math.floor(text.length / 2);
  yield text.substring(0, mid);
  yield text.substring(mid);
}
