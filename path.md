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

## Planned
- Security hardening (WebCrypto signing, revocation)
- Provider registry & encrypted creds manager
