# VPN Direct Documentation

Engineering documentation for the **VPN Direct HarmonyOS NEXT platform** and its shared Core.

## Start here

| Document | Purpose |
| --- | --- |
| [`../README.md`](../README.md) | Project overview and architecture |
| [`harmony/ARCHITECTURE.md`](harmony/ARCHITECTURE.md) | HarmonyOS platform architecture and lifecycle |
| [`harmony/BUILDING.md`](harmony/BUILDING.md) | DevEco, native Core and HAP build guide |
| [`harmony/DEVICE_QUALIFICATION.md`](harmony/DEVICE_QUALIFICATION.md) | Real-device acceptance checklist |
| [`core/ARCHITECTURE.md`](core/ARCHITECTURE.md) | VPN Direct Core architecture |
| [`core/BUILDING.md`](core/BUILDING.md) | Core pins and reproducible build process |
| [`core/PROTOCOL_MATRIX.md`](core/PROTOCOL_MATRIX.md) | Authoritative protocol status |
| [`../core/protocol-matrix.json`](../core/protocol-matrix.json) | Machine-readable protocol matrix |
| [`compatibility/README.md`](compatibility/README.md) | Panels, subscriptions and protocol formats |
| [`compatibility/COMPATIBILITY_MATRIX.md`](compatibility/COMPATIBILITY_MATRIX.md) | Compatibility status |
| [`../CHANGELOG.md`](../CHANGELOG.md) | Project history |
| [`../CONTRIBUTING.md`](../CONTRIBUTING.md) | Contribution and engineering rules |
| [`../SECURITY.md`](../SECURITY.md) | Security reporting |

## Platform vocabulary

```text
ArkUI → VpnExtensionAbility → TUN → N-API → VPN Direct Core → sing-box-lx
```

Source architecture and real-device qualification are tracked separately. A source implementation is not automatically `tested`.

## Core status vocabulary

```text
parsed → compiled → validated → interop-tested → device-tested → production (`tested`)
```

The protocol matrix remains the authority for Core feature status. Do not claim device support without real-device evidence.
