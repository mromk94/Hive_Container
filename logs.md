# LOGS — Hive Container (Chrome Extension)

- Date: 2025-10-30
- Working directory: /Users/mac/CascadeProjects/Hive_container

## Entries
- 20:42 Created Blueprint.md with vision, architecture, and modular TODOs.
- 20:45 Setup extension structure: created hive-extension/{package.json, tsconfig.json, manifest.json, icons/.gitkeep}.
- 20:47 Implemented src/types.ts and src/background.ts skeleton; added message routes and token stub.
- 20:52 Added src/contentScript.ts bridge (page <-> extension) and src/popup.{html,ts} consent UI.
- 20:54 Updated build script to copy popup.html to dist; prepared for npm install + build.
- 20:56 Added demo/index.html to exercise handshake end-to-end.
- 20:58 Added origin validation in background for APP_FORWARD_REQUEST; contentScript now passes page origin.
- 21:00 Fixed TS lint: ensured types.ts is a module; added chrome declaration and param types in background.
- 21:02 Ran npm install in hive-extension (dev deps: esbuild, typescript, @types/chrome).
- 21:05 Ran npm run build → generated dist/background.js, dist/contentScript.js, dist/popup.js and copied popup.html.

## TODOs Snapshot
- ext-setup-structure: completed
- ext-background: in_progress
- ext-content: completed
- ext-popup: completed
- ext-build: in_progress (scripts configured; build next)
- ext-demo: pending
- ext-security: pending
- ext-commit-push: pending

## Notes
- 21:10 Guidance: In Chrome "Load unpacked", select the extension root folder `hive-extension` (the one that contains `manifest.json`). Do not select `demo/` or `index.html` — Chrome requires the folder with `manifest.json`.
- 21:11 If opening `demo/index.html` as file://, enable the extension option "Allow access to file URLs" so the content script runs on the demo page.
- 21:14 Fixed load error: removed missing icon declarations from manifest.json and icons from web_accessible_resources. Reload the extension in chrome://extensions.
- 21:15 Added .gitignore (ignore .DS_Store, node_modules, dist). Preparing to commit and push initial extension scaffold.
- 21:16 Committed scaffold and blueprint/logs/path to git.
- 21:17 Pushed to origin/main (commit 5d6c58f).
- 21:20 Added ES256 WebCrypto utility (crypto.ts) for keypair and signing.
- 21:21 Updated ClientSignedToken type to include alg.
- 21:22 Integrated ES256 signing into background token creation.
- 21:23 Rebuilt extension; dist/background.js updated.
- 21:26 Committing ES256 signing changes and updated background/types.
- 21:27 Pushed ES256 signing changes to origin/main.
- 21:30 Added single-use toggle in popup and passed to token creation.
- 21:31 Implemented session revocation API and single-use enforcement in background (with used-token tracking).
- 21:32 Rebuilt extension; background and popup bundles updated.
- 21:34 Added README for hive-extension with features, setup, demo, security, permissions, roadmap.
- 21:36 Added src/config.ts with origin allowlist helpers.
- 21:37 Narrowed host_permissions and content_script matches in manifest.json to localhost + file URLs.
- 21:38 Enforced allowlist checks in background for token creation and forwarding.
- 21:39 Rebuilt extension; background updated with allowlist checks.
- 21:41 Fixed popup race: store pending session in storage before opening popup; popup reads and clears on load.
- 21:42 Updated contentScript to postMessage with '*' to support file:// pages; rebuild successful.
- 21:43 Reminder: Reload extension and ensure "Allow access to file URLs" is enabled for the demo.
- 21:45 Normalized appOrigin and postMessage targets in demo to support file:// (use '*' and 'file://').
- 21:46 Normalized origin in contentScript for forward requests and used '*' for approved/forward responses.
- 21:47 Rebuilt extension (contentScript + demo adjustments).
- 21:50 Added provider registry UI in popup (selector + token save/clear) and background routing via registry.
- 21:52 Implemented Gemini forwarder in background (map OpenAI-style messages to Gemini generateContent).
- 21:53 Updated manifest host_permissions to allow generativelanguage.googleapis.com.
- 21:54 Rebuilt extension with Gemini support.
- 21:56 Observation: Forward success with echo path on provider=gemini (no API key saved). Guidance: save Gemini key in popup Provider Settings, then Connect → Approve → Forward again.
- 22:00 Added Claude forwarder (Anthropic /v1/messages) and manifest host_permissions for api.anthropic.com.
- 22:02 Added HIVE_DEBUG_INFO endpoint in background and Debug Info button in popup.
- 22:03 Applied black & gold styling to popup (luxury theme).
- 22:04 Rebuilt extension; background and popup updated.
- 22:30 Added Gemini v1→v1beta fallback with detailed tried/usedUrl in background; initial 404s observed for default aliases.
- 22:45 Implemented Preferred Model UI in popup and HIVE_LIST_MODELS endpoint; background respects preferred first.
- 23:00 Implemented auto-discovery via ListModels and auto-cache of successful model; no manual copy needed thereafter.
- 23:10 Styled demo to black/gold and added Forward debug panels (usedUrl, tried) for quick verification.
- 23:15 Suppressed background error when popup not open (consume lastError) and bumped manifest version to 0.1.1.
- 23:20 Rebuilt extension; verified successful forward with gemini-2.5-pro.
- 23:25 Committed changes (preferred model UI, auto-discovery, demo UI, fixes) and pushed to origin/main.
 - 23:35 Implemented Local provider forwarder (tries common endpoints, returns usedUrl/tried, honors single-use).
 - 23:40 Encrypted provider tokens at rest (AES-GCM vault key) and routed background to use encrypted getter.
 - 23:45 Popup UI: added secure storage indicator, dynamic token label (Local → Base URL), human-friendly copy.
 - 23:50 Popup styling upgraded to 3D/animated luxury black & gold; hover/active depth, soft glows.
 - 23:55 Added dev watch scripts (watch:bg/cs/popup, watch) and installed npm-run-all.
 - 23:58 Fixed lint/structure issues: removed misplaced Local block from HIVE_LIST_MODELS; consolidated Local forwarding under APP_FORWARD_REQUEST.
 - 00:05 Demo UX: added loading/steps animation and human-friendly response card with provider/model badges; technical details collapsed.
 - 00:12 Core Vision logged: Portable Persona + Handshake + Shared Consciousness Loop. Summary:
   - Portable persona travels across the web and conditions site AIs upon user approval (origin-scoped).
   - Handshake protocol lets a site request persona, suggest replies, and update context.
   - Shared memory loop maintains rolling transcript and preferences per origin + global.
   - Privacy controls: allowlist/denylist and on-page active banner with quick toggle.
 - 00:13 Next Steps decided:
   1) Persona Profile schema + encrypted storage + popup editor (sliders + notes).
   2) Handshake Protocol v1: GET_PERSONA, SUGGEST_REPLY, UPDATE_CONTEXT with approvals.
   3) Generic Chat Adapter v1: floating “Ask My Hive” near textareas, suggestion panel.
   4) Shared memory per session/origin; inject into provider prompts.
   5) Privacy controls (allow/deny + quick toggle UI).
 - 00:18 Demo fix: removed TS-style "as" cast from escapeHtml to resolve `Unexpected identifier 'as'`; added safe mini-markdown renderer and upgraded token UI to 3D card with mask/copy.

- 13:30 Demo: Added inline cinematic prologue with persona-aware typewriter + particles. Later hardened fallback and slowed speed.
- 13:45 Handshake v1: Implemented HIVE_SUGGEST_REPLY in background, bridged via contentScript; Demo added Suggest Replies UI.
- 14:05 Performance: Added fetch timeouts, reduced tokens, raced endpoints (Gemini v1/v1beta; Local endpoints) for faster suggestions.
- 14:20 Diagnostics: Content script surfaces runtime.lastError back to page to avoid silent hangs.
- 14:35 Popup UX: Introduced 2-tab layout — Chat (default) and Config (existing settings). Chat panel streams via HIVE_POPUP_CHAT.
- 14:36 Background: Added HIVE_POPUP_CHAT (provider-backed chat with persona system) and HIVE_UPDATE_CONTEXT (rolling events per origin/session).
- 14:38 Popup: Wired tab switching and minimal chat send; messages render in chat log.

### 2025-11-01
- 01:25 Continuity: Added buildMemorySummary and buildMemoryMessages; HIVE_PULL_MEMORY now returns hydrated messages for rehydration.
- 01:32 Popup Refresh: replaces chat with hydrated thread from memory instead of summary text.
- 01:36 Memory Recording: Popup now records user messages, assistant replies, import events, and insert actions with origin tags.
- 01:40 UI (Config): Added toggle “Capture page chat to Hive” persisted as hive_capture_page.
- 01:42 Page Bubble: Added “Hydrate” button to inject short recent context preface (no auto-send).
- 01:44 Page Capture: Minimal user send capture on sendAttempt when toggle ON.
- 01:46 Assistant Capture: MutationObserver for OpenAI; later extended to Gemini and Claude heuristics; dedupe by trimmed key.
- 01:50 Loop Guard: Hash-based dedupe for persona and recent context prefaces (per-origin last hash in storage + window cache).
- 01:55 Build: npm run build succeeded (background/contentScript/popup bundles updated).

- 03:05 UI: On-page bubble refined (pill group, blur backdrop) with overlap avoidance.
- 03:08 Behavior: Added "Auto-hydrate on focus" toggle and page-side focus sync via HIVE_SYNC.
- 03:12 Vision: Added "Allow page reading (vision)" toggle. When ON, requests optional host permission for current origin and injects content script.
- 03:14 Read Button: Added "Read" in on-page bubble to inject Deep Page Context (title, selection, summary of text blocks, and images: alt/caption/src), with hash dedupe.
- 03:16 Suggest Flow: When page reading is allowed, suggestions prepend SYSTEM page snapshot automatically.
- 03:18 Manifest: Expanded optional_host_permissions to http(s)://*/* for per-site opt-in; kept content_script matches narrow. Uses chrome.scripting.executeScript on grant.
- 03:20 Mobile Bridge: Added window.postMessage relays HIVE_MOBILE_SYNC/PULL/RECORD to support external mobile surfaces.
- 05:20 Chat UX: Multiline composer (Shift+Enter newline), Output format selector (Plain/Markdown/HTML), markdown/html rendering with sanitization.
- 05:28 Dock: Added right-side expandable dock with iframe to popup; persisted width and open state; viewport-aware clamping.
- 05:34 Popup: Auto-detect embedded and switch to responsive full-height layout (flex chat + sticky composer).
- 05:38 Compact UI: Consolidated floating controls into single side tab with compact action menu; hid banner/bubble by default.
- 05:45 Detection: Added manual “Rescan AI” and visual cue (tab glow) when AI detected.
- 05:52 Manifest: Added host_permissions and content_script matches for copilot.microsoft.com, *.bing.com, grok.com, elevenlabs.io, *.elevenlabs.io, www/meta.ai, www/*.canva.com.
- 05:58 Manifest (more): Added github.com, *.github.com, and new-frontend-irt9943l2-adolphuslarrygmailcoms-projects.vercel.app.
- 05:59 ContentScript: Console debug on injection; expanded knownHosts list accordingly.
- 06:00 Build: npm run build succeeded (background/contentScript/popup bundles updated). Reload extension to test.

### 2025-11-25
- 19:55 OMK Container: scaffolded `omk-container/` monorepo with:
  - `mobile/` Flutter app skeleton (Android-first), `main.dart`, and baseline unit test.
  - `hive-bridge/` Node.js mock server (`/health`, `/analyze`, `/escalate`, `/sync-bloom`).
  - `native-plugins/` and `security-db/` placeholders for Kotlin/Swift plugins and SQLite/Vault schemas.
  - `docs/TECH-DECISION-001.md` (Flutter + Kotlin + Node + SQLite + TFLite stack) and `docs/MONOREPO-LAYOUT.md`.
  - `scripts/dev-bootstrap.sh` (macOS/Linux) and `scripts/DEV-BOOTSTRAP-WINDOWS.md` for dev setup.
- 19:58 CI: added `.github/workflows/omk-container-ci.yml` to run Hive Bridge tests, Flutter tests, and Android debug build on pushes/PRs.
- 20:00 Governance: added `omk-container/CODE_OF_CONDUCT.md` and `omk-container/CLA.md`.
- 20:02 Docs: expanded `omk-container/README.md` with mission, architecture ASCII diagram, quickstart, contributing, license, and contact.
- 20:04 Blueprint: updated `Blueprint.md` with section 17 describing OMK Container mobile + Hive Bridge architecture and its role in the AI-Verse/Hive ecosystem.
 - 20:10 OMK UX (mobile): added in-app floating bubble overlay with draggable position and expand/collapse into a mini chat panel.
 - 20:12 Mini chat: implemented message list, input field, and quick actions (Analyze page, Summarize, Report phishing) with Semantics labels and minimum touch sizes.
 - 20:14 Settings: created Settings screen with floating assistant toggle, history purge, TTL slider for security memory, model selection dropdown, and link into Permissions screen.
 - 20:16 Permissions: designed Permissions screen + reusable "Why we ask for this" modal for overlay, VPN, accessibility, screenshots, and microphone, with user-facing copy and legal phrasing.
 - 20:18 Onboarding: added 3-step onboarding flow (mission, privacy, quick setup) with skip and later opt-in options, gated by onboardingCompletedProvider.
 - 20:20 A11y/i18n: introduced custom Strings localizations (EN, placeholders for Nigerian Pidgin, FR, ZH), hooked into flutter_localizations, added Semantics labels and scalable text.
  - 20:26 OMK VPN (Android): added Kotlin OmkVpnService skeleton (VpnService) that establishes a local TUN interface, loops over packets, and forwards metadata into DnsProxy + PacketMetadataCollector. Included manifest/permission snippet for BIND_VPN_SERVICE and foreground service.
  - 20:28 DNS proxy: created DnsProxy skeleton that forwards DNS queries to upstream DNS (8.8.8.8) and logs query/response metadata as a placeholder for security DB integration.
  - 20:30 TLS metadata: implemented TlsMetadataExtractor utility with SHA-256 certificate fingerprinting, issuer/subject/validity logging, and a JVM test harness using HttpsURLConnection.
  - 20:32 Packet metadata: added PacketMetadataCollector + PacketInfo model that separates connection metadata from payload and enforces a deepAnalysisEnabled flag before payload size is considered.
  - 20:34 iOS NE plan: documented IOS-NE-PLAN.md outlining NEPacketTunnelProvider + DNS proxy design, entitlements, App Store policy constraints, and metadata-only default model.
  - 20:38 Accessibility capture: added OmkAccessibilityService + AccessibilityTextCapture to walk visible nodes, capture text + bounding boxes, and run a native PII sanitizer before logging.
  - 20:40 Screenshot OCR: defined ScreenshotOcr skeleton that accepts a Bitmap and will later map ML Kit/Tesseract text blocks into {text, confidence} OcrBlocks.
  - 20:42 URL utils: implemented canonicalizeUrl() in Dart (url_utils.dart) to normalize scheme/host/path, strip trackers, and compute sha256 hash for memory loop keys.
  - 20:44 Content fingerprint: added ContentFingerprint + buildFingerprint() and documented schema (CONTENT-FINGERPRINT-SCHEMA.md) combining url_hash, title_hash, screenshot pHash.
  - 20:46 Compact context snapshot: defined COMPACT-CONTEXT-SNAPSHOT.md schema for {url_hash, host, cert_summary, top_text_snippets, screenshot_hash, navigation_chain, local_features} (~2–4KB) for escalations.
  - 20:48 Privacy sanitizer: implemented stronger Dart-side PrivacySanitizer to strip emails, cards, SSNs, and long digit sequences before any cloud transmission.
  - 20:52 Security memory DB: added security_memory SQLite schema + SecurityMemoryDb repository with indices, TTL cleanup, and upsertFromSnapshot for compact context storage.
  - 20:54 Bloom client: created BloomClient + BloomFilter in Dart to sync daily threat bloom metadata from Hive Bridge /sync-bloom and support mayContainHost(host) checks.
  - 20:56 Vector store: introduced lightweight in-memory VectorStore with cosine similarity to compare URL snapshots against flagged patterns.
  - 20:58 Cache UI: built SecurityCacheScreen to view recent security_memory entries, pin/unpin verdicts, refresh list, and purge cache.
  - 21:00 Decision flow: implemented SecurityDecisionEngine (bloom → security_memory → on-device classifier → Hive Bridge /analyze) with path instrumentation for each decision.
  - 21:04 URL risk spec: documented URL risk on-device classifier feature vector & dataset schema (URL-RISK-FEATURES-SPEC.md).
  - 21:06 Training pipeline: added ml/url_risk_training.py + requirements.txt to engineer features and export a quantized TFLite model from Keras.
  - 21:08 TFLite wrapper: introduced UrlRiskFeatures/UrlRiskModel in Dart using tflite_flutter, with SAFE/SUSPECT/MALICIOUS thresholds and crypto/shared_preferences wiring.
  - 21:10 Model versioning: documented URL-RISK-MODEL-VERSIONING.md and added UrlRiskModelStore for on-device model install + rollback based on Hive Bridge metadata.
  - 21:12 LLM prompts: drafted LLM-ESCALATION-PROMPTS.md with compact templates for verdict JSON, user summaries, threat intel, remediation, and safe-override justification.
  - 21:14 Escalation API: documented ESCALATION-API.md for Hive Bridge /escalate with context body, JSON verdict response, rate limiting, and token budget fallbacks.
  - 21:16 LLM cost policy: added LLM-COST-POLICY.md describing model tiering (small/medium/large), caching, and per-tenant token budgets.
  - 21:18 LLM output schema: defined LLM-OUTPUT-SCHEMA.md plus llmOutputSchema.mjs validator for {verdict, confidence, summary_1line, evidence[], actions[]} responses.
  - 21:20 Guardrails: created LLM-GUARDRAILS.md system prompts enforcing context-only reasoning and INS UFFICIENT_DATA behavior when evidence is weak.
  - 21:22 Threat aggregator: added threatAggregator.mjs skeleton to aggregate feeds and produce bloom + high-confidence malicious deltas for /sync-bloom.
  - 21:24 Escalation worker: implemented escalationWorker.mjs to apply quick heuristics, pick model tier, validate LLM output, and shape /escalate responses.
  - 21:26 Sync protocol: documented COMPACT-SYNC-PROTOCOL.md for signed daily deltas (bloom, domain hashes, high-confidence list) and REST endpoints.
  - 21:28 Backend privacy/auth: wrote BACKEND-PRIVACY-AUTH.md plus auth.mjs + auditLog.mjs skeletons for API keys, dev auth, and metadata-only audit logs.
  - 21:30 NS-Stage-3 CNL: implemented ContextNormalizationLayer + SemanticPacket in Dart and wired it into analyze_page_action to emit cached semantic packets with metadata (timestamp, source, intent_confidence, action_type, summary_text).
  - 21:32 NS-Stage-4 memory loop: added MemoryMatcher for fuzzy cache hits over security_memory, set 30-day TTL for bridge/analyze_action entries, and integrated it into SecurityDecisionEngine to avoid redundant AI calls for similar contexts.
  - 21:36 NS-Stage-6 intent router: implemented IntentRouter with confidence-based priorities across security/summarization/recommendation intents and tied it to SemanticPacket + SecurityCheckpoint for future orchestration.
  - 21:38 NS-Stage-7 LLM interaction: added llmInteraction.mjs and LLM-INTERACTION-PROTOCOL.md to define priority task queueing, context-aware prompt assembly, streaming stubs, and offline fallback behavior.
  - 21:40 NS-Stage-8 Hive sync: implemented MemorySyncClient on mobile and /memory-sync + memorySync.mjs on Hive Bridge for incremental, batched uploads of processed security_memory entries with audit logging.
  - 21:42 NS-Stage-9 floating UX: extended FloatingBubbleOverlay to support collapsed insight icon, quick actions via mini chat, adaptive edge clamping, and 5s auto fade-out after inactivity.
  - 21:44 NS-Stage-10 autonomy: added AutonomyEngine for per-intent reinforcement weights, integrated it into IntentRouter priorities, loaded weights on startup, and documented the v2 multi-agent roadmap (NEURAL-SWITCHBOARD-V2-ROADMAP.md).
  - 21:46 Phase 1 hybrid core: added NodeIdentity, connectivity/signal scaffolding, LocalLightModel, TimeSyncedSnapshot, L-Mesh docs, llmRegistry, and wired LLM interaction to use registry + Larry-State baseline persona.
  - 21:48 Phase 2 local mesh: added MeshPeer/Discovery/Leader, CoopCache, MeshEventBus, AiGuardianService, MeshConsensus, and OfflineEnvelopeStore scaffolding to support WiFi/BLE-based hive formation and cooperative caching once native transports are wired.
  - 21:50 Phase 3 federated twins: added TwinIdentity/State/mesh channel, predictive cache planner, cluster coordinator, environment triggers, TwinResonanceMetric, FEDERATED-TWINS.md, and UNWIRED-COMPONENTS.md to support offline twin learning, resonance, and merge-on-reconnect flows.
  - 21:52 Phase 4 AR layer: added AR twin/realm models, mesh health visuals, gesture/audio/voice intent types, proximity stories, AI handshake events, environment mapping, and AR-INTERACTION-LAYER.md while tracking all unwired AR pieces in UNWIRED-COMPONENTS.md.
  - 21:54 Phase 5 security/memory: added logical LocalMeshCA, LarryThreatAnalyzer, MeshLedger, NodeQuarantineManager, SecurityTicketing, MeshPersistenceHelper, and documented unwired crypto/persistence paths in UNWIRED-COMPONENTS.md (security memory loop already implemented earlier).
  - 21:56 Phase 6 community: added community board, knowledge pool, event tagging, learning pulse, AI scouts, community milestones, group problem sessions, resource tracker, regional gateway, AI village cluster models, and COMMUNITY-INTELLIGENCE.md, with all unwired paths tracked in UNWIRED-COMPONENTS.md.
  - 21:58 Phase 7 optimization: added packet scheduling, emergency SMS/sync policy/startup cache/dialogue smoothing/predictive routing/shadow LLM/topology evolution/mirror node models and UNIFIED-INTELLIGENCE-PROTOCOL.md, with all remaining wiring tracked in UNWIRED-COMPONENTS.md.
  - 22:00 Wiring slice A: made SecurityDecisionEngine escalation offline-safe, added NetworkTelemetry, wired telemetry into /analyze + /memory-sync, used PacketScheduler for memory-sync payloads, and surfaced ConnectivityAdvisor mode in mini chat analyze output.
  - 22:02 Wiring slice B: invoked AiGuardianService from analyze_page_action so high-risk decisions emit MeshEventBus securityWarning events (still local-only until mesh transports are wired).
  - 22:04 Wiring slice C: added OfflineEnvelopeWorker to drain and log offline envelopes (security_ticket, etc.) as a precursor to forwarding them to Hive Bridge or mesh admins.
  - 22:06 Wiring slice D: introduced MeshRoutingPolicy to consult NodeQuarantineManager when filtering peers (ready for use once real mesh discovery is wired).
  - 22:08 Wiring slice E: integrated LarryThreatAnalyzer into the on-device classifier path for offline mode, so offline decisions use the light model wrapper with explicit path markers.
  - 22:10 Wiring slice F: added MeshPacketBuilder that uses TimeSyncedSnapshot and SignalTelemetry to construct L-Mesh context packets per protocol (ready for future mesh transports).
  - 22:12 Wiring slice G: added /twin-sync on Hive Bridge plus TwinStateStore/TwinSyncClient and hooked it after memory-sync to opportunistically sync TwinSnapshot.
  - 22:14 Wiring slice H: added MeshTransportBridge to enqueue mesh events into OfflineEnvelopeStore, MeshAlerts controller/provider, and a MeshStatusScreen accessible from the main app bar to display basic mesh security alerts and mode.
  - 22:16 Wiring slice I: added basic backend infra scaffolding — Postgres verdict_cache schema, db.mjs connector, verdictStore.mjs, Prometheus metrics middleware with /metrics, simple in-memory rateLimiter, and docker-compose.yml for Postgres + Hive Bridge (Terraform sketch in infra/README.md).

### 2025-11-27 — OMK Container mobile wallet + Queen LLM relay
- 20:30 WebView importer: finalized multi-provider DOM-based extractor for ChatGPT `/s/...` shares and generic LLM chats (Gemini, Claude, Grok, DeepSeek, Copilot, Perplexity, etc.), with visible in-app browser and explicit Capture button.
- 20:40 Persona builder: enriched `PersonaBuilderService` with on-device heuristics for traits (enthusiasm, curiosity, formality, optimism), interests (keywords), and roles (founder/engineer/designer/… from chat text).
- 20:50 Android permissions: added INTERNET to OMK mobile main manifest so release builds can reach Queen/LLM endpoints; aligned WebView user agent with mobile Chrome.
- 21:00 Wallet models: introduced `OmkWalletBalance` and `WalletTransaction` plus JSON helpers in `wallet_models.dart` for SharedPreferences caching.
- 21:05 Wallet service: implemented `OmkWalletService` (Dio + Queen base URL) with `fetchBalance`, `refreshBalance`, and `spendOmk` methods that talk to `/wallet/balance` and `/wallet/spend` and keep a cached balance.
- 21:10 Wallet UI: added `WalletScreen` with balance card, soft top-up placeholder, and future usage section; added `OmkBalancePill` widget surfaced in the OMK Assistant header.
- 21:20 LLM relay: created `OmkLlmClient` that estimates token cost per model, calls `OmkWalletService.spendOmk` before cloud requests, and forwards to Queen `/llm/generate` for models (`gpt`, `gemini`, `claude`, `grok`, `deepseek`, `local`).
- 21:25 Consciousness engine: re-routed `ConsciousnessEngine.generateReply` to use `OmkLlmClient` + `OmkWalletService` instead of direct provider APIs, mapping `ConsciousnessProviderId` → logical model ids.
- 21:30 Insufficient OMK UX: added `InsufficientOmkException` and wired `MiniChatController.sendWithConsciousness` to surface a system-style assistant message guiding the user to top up or switch to local mode instead of silently failing.
- 21:40 Settings wiring: exposed OMK Wallet entry in Settings → opens `WalletScreen`; kept model selection wiring for future Queen-backed model registry.
- 21:50 Build: `flutter build apk` succeeds for OMK Container mobile with wallet + LLM relay code; ready for device-side wallet + Queen integration tests.
