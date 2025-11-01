# PATH — Hive Container (Chrome Extension)

Root: /Users/mac/CascadeProjects/Hive_container

## Created
- Blueprint.md
- hive-extension/
  - package.json
  - tsconfig.json
  - manifest.json
  - README.md
  - icons/.gitkeep
  - src/
    - types.ts
    - background.ts
    - contentScript.ts
    - popup.html (now 2 tabs: Chat + Config)
    - popup.ts (tab switching + Chat send via HIVE_POPUP_CHAT)
    - crypto.ts
    - config.ts
    - registry.ts
  - demo/
    - index.html
  - dist/ (built)

## New/Updated message handlers
- background.ts
  - HIVE_SUGGEST_REPLY (persona-aware suggestions)
  - HIVE_UPDATE_CONTEXT (rolling events per origin/session)
  - HIVE_POPUP_CHAT (provider-backed chat for popup)
  - HIVE_PULL_MEMORY (returns events + hydrated messages + persona/user + vault)
  - HIVE_RECORD_MEMORY (records user/page/gpt events into hive_memory, auto-tunes persona)
  - HIVE_SYNC (sync worker endpoint returning vault + last state hash)

## Continuity features (files)
- hive-extension/src/background.ts
  - buildMemorySummary(), buildMemoryMessages(), buildThreadHistory()
  - Vault helpers: computeStateHash(), getVault(), setVault(), refreshVault()
- hive-extension/src/popup.ts
  - Refresh button hydrates chat with messages from HIVE_PULL_MEMORY
  - Records: user messages, assistant replies, import events, insert actions
  - Behavior toggles: auto-tune persona, capture page chat
- hive-extension/src/popup.html
  - Added Config toggle: Capture page chat to Hive
- hive-extension/src/contentScript.ts
  - On-page bubble: Use my Hive, Hydrate buttons
  - Minimal page send capture; assistant capture for OpenAI/Gemini/Claude (MutationObserver)
  - Hash-based dedupe for persona/context injection

## Planned
- Security hardening (WebCrypto signing, revocation)
- Provider registry & encrypted creds manager
