# What's New — VPN Direct 1.0.10

Release date: 2026-09-08  
Git tag: `v1.0.10`

## App Store / short What's New

- Import OpenVPN (`.ovpn`), OpenConnect, and Tailscale endpoint JSON from File / paste
- MASQUE CONNECT-UDP (RFC 9298) outbound support in Core + JSON import
- Broader public harvest coverage (including ML-KEM / VLESS PQ encryption samples)
- Docs refreshed for the current import surface; obsolete audit drafts removed

## Engineering detail

### Tunnel / endpoint import
- `OpenVPNConfigAdapter` — classic client `.ovpn` → `openvpn-client` endpoint
- `OpenConnectConfigAdapter` — JSON / AnyConnect-ish XML → `openconnect` endpoint
- `TailscaleConfigAdapter` — `type: tailscale` JSON (auth_key / control_url)
- File importer accepts `.ovpn`, `.conf`, `.xml`, `.txt`, `.json`; local import runs `normalizeRemoteContent`
- Graph builder treats OpenVPN / OpenConnect / Tailscale as top-level `endpoints` (same path as WG/AWG)

### MASQUE CONNECT-UDP
- New Core outbound `type: masque-connect-udp` (H3 Extended CONNECT + HTTP datagrams)
- Capability `masqueConnectUDP` / `VPNDirectSupportsMASQUEConnectUDP()`
- Swift: `MasqueConnectUDPAdapter` + detector kind `masqueConnectUDPJSON`
- Spec: `core/sing-box/SPECS/TASKS/025-MASQUE_CONNECT_UDP_OUTBOUND/SPEC.md`
- **Requires Libbox rebuild** (`with_quic`) to flip the capability in the linked xcframework

### Libbox Darwin tags
- `build_libbox` enables `with_tailscale` (+ `ts_omit_*`) again for Tailscale endpoints
- OpenVPN / OpenConnect tags were already on Darwin builds

### Harvest / tests
- Public catalog expanded (Code-Leafy configs remain 404; barry-far ML-KEM harvest works)
- `TunnelEndpointImportTests` covers OVPN / OpenConnect / Tailscale / CONNECT-UDP import→graph

### Docs
- Architecture / matrix / compatibility matrix / docs index aligned to v1.0.10
- Removed stale Core 0.1 audit/plan drafts that contradicted shipped code

## Device note

SFI Wi-Fi install/launch on physical iPhone remains the qualification path (`docs/device/`). Packet Tunnel connect still needs interactive VPN permission on device.
