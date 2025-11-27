# L-Mesh Topology — OMK Hybrid Grid v2.0

Defines how OMK Container nodes form local meshes and connect to Hive
Bridge and cloud providers.

## Node Roles

- **leaf** — end-user device (phone, tablet, laptop) running OMK
  Container.
- **relay** — device that can bridge multiple local transports (WiFi
  Direct, BLE, hotspot) but does not need direct cloud connectivity.
- **gateway** — node with stable Internet that can proxy traffic
  (optional) to Hive Bridge / Queen Cloud APIs.

## Link Types

- **wifi_direct** — peer-to-peer WiFi connections.
- **ble** — Bluetooth LE links for low-bandwidth control / beacons.
- **hotspot** — ad-hoc AP or tether connection.
- **cloud** — HTTPS via Hive Bridge / other APIs.

## Topology Modes

- **cloud_only** — leaf ↔ gateway (Hive Bridge) only.
- **local_mesh_only** — leaf ↔ leaf/relay/gateway over local links, no
  Internet.
- **hybrid** — local mesh used for short-range sync + cooperative
  inference; gateway still contacts cloud when available.

## Data Model

Expressed as simple JSON structures to be shared across mobile and
backend for diagnostics and planning.

```jsonc
{
  "node_id": "node-abc",
  "role": "leaf", // leaf | relay | gateway
  "links": [
    {
      "type": "wifi_direct", // wifi_direct | ble | hotspot | cloud
      "peer_id": "node-def",
      "rssi": -55,
      "latency_ms": 12,
      "capacity_kbps": 5000
    }
  ],
  "cloud_reachable": true
}
```

Higher-level planners (IntentRouter, AutonomyEngine, future Agent
Planner) can use this to decide what work to do where (local vs cloud).
