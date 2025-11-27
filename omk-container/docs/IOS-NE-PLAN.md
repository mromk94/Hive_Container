# iOS Network Extension Plan — OMK Container

## Goal

Mirror the Android OMK VPN capabilities on iOS using **Network Extension** while
respecting App Store policy constraints and privacy promises:

- Capture DNS and basic connection metadata.
- No TLS MITM; only metadata (cert fingerprints, issuer, SNI) where possible.
- User-visible, revocable controls and clear explanations.

## Components

1. **NEPacketTunnelProvider**
   - Implements a packet tunnel that receives IP packets from the OS.
   - Parses headers and forwards metadata to the OMK app via IPC / shared container.
   - Enforces the same "no payload unless Deep Analysis explicitly enabled" rule.

2. **DNS Proxy (NEAppProxy / custom resolver)**
   - Option A: Use `NEDNSProxyProvider` if app type allows.
   - Option B: Implement DNS handling on top of NEPacketTunnelProvider by intercepting UDP/53.
   - Logs query hostnames and response metadata to OMK security memory.

3. **Control app (OMK iOS app)**
   - Hosts the persona UI and VPN controls.
   - Starts/stops the packet tunnel via `NETunnelProviderManager`.
   - Presents consent, onboarding, and permission explanations consistent with Android.

## Entitlements & Capabilities

- **Required entitlements** (subject to Apple review):
  - `com.apple.developer.networking.networkextension` with:
    - `packet-tunnel-provider`
    - optionally `dns-proxy` if using NEDNSProxyProvider.
- **App capabilities**:
  - Background modes: `network` and possibly `voip`/`fetch` depending on design.

These entitlements require:
- An Apple Developer account.
- A Network Extension request/justification to Apple.

## App Store Policy Considerations

- Clearly describe:
  - What traffic is inspected (metadata vs payload).
  - Whether any data leaves the device and under what conditions.
  - That the app does **not** sell or monetize traffic data.
- Avoid generic "VPN" marketing that implies full privacy while sending data elsewhere.
- Provide an in-app privacy policy and link it from App Store listing.

## Data Handling Model

- Default: **metadata-only** collection
  - Source/destination IP and port
  - Protocol (TCP/UDP)
  - DNS hostnames
  - TLS certificate fingerprints and issuer (where accessible)
- Deep Analysis (opt-in, per-site/session):
  - May temporarily allow limited payload sampling for security analysis (e.g., phishing detection).
  - Always explained via a modal similar to Android "Why we ask for this".
  - Short-lived and revocable; state stored locally.

## Lifecycle

1. User enables OMK VPN in the iOS app.
2. App configures `NETunnelProviderManager` with NEPacketTunnelProvider.
3. Extension starts, establishes tunnel, and begins metadata collection.
4. On network changes or app termination:
   - Tunnel provider should gracefully stop or reconnect.
   - Provide clear status to the host app.
5. User can disable OMK VPN at any time from the app or iOS Settings.

## Future Steps

- Define a shared protobuf/JSON schema for security events so Android and iOS
  can share analysis and Vault sync pipelines.
- Implement a small on-device rule engine to flag risky connections without
  sending raw data off-device.
