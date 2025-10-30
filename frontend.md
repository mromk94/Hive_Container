
---

## 💻 **frontend.md**

# Frontend.md — Frontend Architecture & UI/UX Spec

## Purpose
Frontend for the AI Personality Metaverse Proxy must support onboarding, personality editing, live session monitoring, playback summaries, and controls for permission/risk levels. It should integrate tightly with Hive Container (extension/UI) and the backend Bridge APIs.

## Core Pages / Views
1. **Landing / Intro**
   - Short explainer, demo video, and "Create Personality" CTA.
2. **Onboarding Wizard**
   - Step 1: Identity & Tone (select style, voice, ethics).
   - Step 2: Data sources (import chat logs, social media, preferences).
   - Step 3: Risk & Financial Limits.
   - Step 4: Snapshot & Consent (stores snapshot to Hive Container).
3. **Dashboard**
   - Active sessions, recent summaries, wallets, reputation, connected metaverses.
4. **Personality Editor**
   - Adjust tone sliders (Formal — Casual, Curious — Reserved).
   - Memory editor (view, redact, pin memories).
   - Behavior policies (toggle rules, spending caps).
5. **Live Session View**
   - Real-time timeline, minimal live chat, "Take Control" button.
6. **Playback / Summary**
   - Auto-generated highlights, transcripts, media captures.
   - Actions list (what was done, assets traded, contacts made).
7. **Settings / Security**
   - KYC, 2FA, encryption keys, export data, delete personality.

## Frontend Stack Recommendations
- **Framework**: React + Next.js (for hybrid SSR + client).
- **Styling**: Tailwind CSS (rapid, consistent).
- **State**: Redux Toolkit / Zustand for client state; React Query for server state sync.
- **Realtime**: WebSocket (Socket.IO or native WebSocket) for sessions; optional WebRTC for voice/video streaming.
- **Auth**: OAuth2 + JWT; integrate Hive Extension for proof-of-consent handshakes.
- **Testing**: Jest + React Testing Library + Playwright for e2e.

## UI/UX Patterns
- Progressive disclosure — hide advanced automation options by default.
- Safety-first defaults — conservative spending limits, opt-in autonomous actions.
- Clear audit trails — every action must be explainable and link to the recorded session.
- Accessible design — WCAG AA compliance, keyboard-first navigation.

## Components & Layouts
- **TopNav**: Logo, Search, Notifications, User Menu.
- **SideNav**: Dashboard, Personalities, Sessions, Wallet, Settings.
- **Cards**: Session summary, wallet snapshot, quick actions.
- **Modal Systems**: Consent modal, takeover modal, emergency-stop.
- **Toast/Alerts**: Important security events (e.g., "Personality attempted transaction over $X — blocked").

## Integration Points
- Bridge API endpoints for listing adapters, launching sessions, fetching recordings.
- Webhook subscriptions for session events and billing.
- Connectors to wallets (Web3 modal, Stripe/Fiat via backend).
- Analytics hooks: event-based instrumentation (Amplitude or Segment).

## Accessibility & Internationalization
- Localization (i18n) from day one — support English, French, Chinese (configurable).
- Screen reader support and color-contrast safe palette.

## Example Component Tree (simplified)
- App
  - TopNav
  - SideNav
  - MainRouter
    - Dashboard
    - PersonalityEditor
    - SessionPlayer
    - Settings

## MVP Frontend TODOs
1. Build onboarding wizard (forms, connectors).
2. Dashboard with recent sessions and "create snapshot".
3. Live Session viewer (text-based) + takeover button.
4. Playback viewer with summary cards.
