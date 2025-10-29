# Security Policy (Hive Container)

Hive Container is the client-side continuity and consent layer for AI-Verse. This policy aligns with AI-Verse Architecture sections 7.1–7.4 and focuses on extension/app security, consent tokens, and data handling.

---

## Reporting a Vulnerability
- Use GitHub Security Advisories for private disclosure.
- If email is needed, share a minimal PoC and impact; do not include real user data.
- We acknowledge receipt and coordinate remediation and disclosure.

## Scope
- This repo contains extension/app docs and example code.
- Findings of interest include:
  - Origin validation bypass in page↔extension messaging.
  - Consent token (ClientSignedToken) forgery/reuse beyond TTL.
  - Key leakage or improper storage of private keys/provider tokens.
  - Revocation not taking effect or reuse of revoked sessions.

## Data Handling Principles (Frozen)
- Least exposure: never forward raw memories; only intended action outputs.
- Consent tokens: short-lived TTL, bound to origin and subject; rotation & revocation supported.
- Key custody: private keys stay client-side; prefer OS keystore; otherwise encrypt at rest with AES-GCM (WebCrypto) using passphrase-derived keys.
- Redaction & export: snapshot redactions are irreversible; preserve audit stubs; non-exportable content is never exported.
- Emergency stop: user-triggered STOP suppresses further forwarding and invalidates the active session.

## Tokens, Secrets, and PII
- Never commit secrets or provider tokens to the repo.
- Do not handle real PII in examples.
- Use placeholders/sanitized data for demos/tests.

## Responsible Disclosure
- Provide description, impact, and minimal PoC.
- Allow a reasonable remediation window before public disclosure.
- Avoid testing against real users or production data.

## References
- AI-Verse Architecture: https://github.com/mromk94/AIverse-Hub/blob/main/docs/ARCHITECTURE.md
- AI-Verse Glossary: https://github.com/mromk94/AIverse-Hub/blob/main/docs/GLOSSARY.md
