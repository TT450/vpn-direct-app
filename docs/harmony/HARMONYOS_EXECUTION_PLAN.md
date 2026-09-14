# VPN Direct — HarmonyOS NEXT Execution Plan

> **Branch:** `harmony-os-app`  
> **Goal:** ship a real, production-quality VPN Direct client for HarmonyOS NEXT and publish it through Huawei AppGallery.

This is the execution checklist for the HarmonyOS port. Work proceeds from the VPN datapath outward: first a buildable application, then a real TUN, then the native Core, then a verified tunnel, then product features and release qualification.

## Critical API boundary: third-party VPN vs system VPN

HarmonyOS exposes two different VPN API layers and they must not be confused:

- **Third-party VPN:** `vpnExtension` / `VpnExtensionAbility` from `@kit.NetworkKit`. This is the path VPN Direct uses. Huawei's third-party VPN guide states that this capability is intended for building custom VPN clients, that the app implements the tunnel internals itself, and that `ohos.permission.INTERNET` is required. The first connection also goes through the system VPN trust/authorization UI.
- **System VPN management:** `@ohos.net.vpn` is a system API. Its `setUp`, `protect`, and `destroy` operations require `ohos.permission.MANAGE_VPN` and are restricted to system applications. We therefore **must not add `MANAGE_VPN` to VPN Direct as if it were a normal third-party runtime permission**. If a future distribution target requires a system/privileged VPN integration, that is a separate product/signing track.

This distinction is now part of the implementation gate: use `vpnExtension` for the consumer AppGallery client and verify permission/signing requirements against the target HarmonyOS SDK before release. citeturn2search0turn2search4

## Non-negotiable architecture

```text
ArkUI / ArkTS
      │
      ▼
VPN Direct application state
      │
      │ startVpnExtensionAbility(Want)
      ▼
VpnExtensionAbility
      │
      ▼
VpnConnection → HarmonyOS TUN fd
      │
      ▼
N-API bridge
      │
      ▼
VPNDirectCore 0.1.0
      │
      ▼
sing-box-lx v1.14.0-lx.35
      │
      ▼
VPN endpoint
```

The HarmonyOS layer is a platform adapter. The existing VPN Direct Core remains the source of truth for tunnel processing and protocol capabilities. No private backend code, credentials, or downloadable executable code belongs in this public repository.

---

## M1 — Project Foundation

**Definition of done:** a clean DevEco build produces a valid HAP.

- [ ] Complete HarmonyOS Stage-model project structure
- [ ] Configure AppScope and entry module
- [ ] Configure phone/tablet device targets
- [ ] Configure HarmonyOS SDK/API and native toolchain
- [ ] Add EntryAbility and initial ArkUI page
- [ ] Add application resources and icons
- [x] Declare `ohos.permission.INTERNET`
- [x] Register `VpnExtensionAbility`
- [ ] Produce a signed/debug HAP locally
- [ ] Verify installation on a real HarmonyOS NEXT device

## M2 — VPN Platform Adapter

**Definition of done:** HarmonyOS creates and destroys a real VPN TUN reliably.

- [x] Implement `VpnExtensionAbility` lifecycle scaffold
- [x] Create `VpnConnection`
- [x] Create VPN configuration
- [x] Request TUN creation through `VpnConnection.create`
- [x] Generate a VPN ID before creating the connection
- [x] Implement deterministic start/stop lifecycle
- [x] Make repeated start/stop idempotent in the adapter
- [x] Handle extension destruction safely
- [ ] Validate IPv4 routes on a real device
- [ ] Validate IPv6 routes on a real device
- [ ] Validate DNS configuration on a real device
- [ ] Validate Wi-Fi/cellular transitions
- [ ] Test screen lock/background lifecycle

## M3 — Native VPN Direct Core

**Definition of done:** `libvpndirect_core.so` is a real HarmonyOS ARM64 native artifact built from the repository's pinned Core.

- [ ] Define the stable Harmony Core ABI
- [x] Implement native start/stop entry points
- [x] Make ArkTS/native status codes explicit
- [ ] Make native Core calls non-blocking for ArkTS
- [x] Implement thread-safe bridge lifecycle state
- [x] Implement error propagation to ArkTS
- [ ] Build VPN Direct Core for HarmonyOS/OpenHarmony ARM64
- [ ] Preserve Core version `0.1.0`
- [ ] Preserve `sing-box-lx` revision `v1.14.0-lx.35`
- [ ] Apply the repository's public Core overlays
- [ ] Verify capabilities are fail-closed
- [ ] Package `libvpndirect_core.so` into the HAP

## M4 — First Working VPN

**Definition of done:** pressing CONNECT on a real Huawei device establishes a real tunnel and routes internet traffic through a known-good VPN endpoint.

- [ ] Connect TUN fd to the native Core
- [x] Pass a validated profile as data through the extension launch `Want`
- [ ] Start Core with one known-good profile
- [ ] Establish a real VPN session
- [ ] Verify IPv4 internet traffic
- [ ] Verify DNS resolution
- [ ] Verify UDP traffic
- [ ] Verify disconnect
- [ ] Verify reconnect
- [ ] Verify malformed profile handling
- [ ] Verify endpoint-unavailable handling
- [ ] Verify Core shutdown on extension destruction

## M5 — Network and protocol qualification

**Definition of done:** the tunnel is stable across the real operating conditions we support.

- [ ] IPv4 full-tunnel routing
- [ ] IPv6 full-tunnel routing
- [ ] DNS leak checks
- [ ] IPv4/IPv6 exit-IP checks
- [ ] Wi-Fi qualification
- [ ] Cellular qualification
- [ ] Wi-Fi → cellular transition
- [ ] Cellular → Wi-Fi transition
- [ ] Background execution
- [ ] Screen lock/unlock
- [ ] Long-running tunnel stability
- [ ] Memory/resource stability
- [ ] Core error recovery
- [ ] Protocol matrix updated only from real evidence

## M6 — Product layer

**Definition of done:** VPN Direct is a complete consumer application rather than a tunnel demo.

- [ ] Home screen
- [ ] Connection status and lifecycle UI
- [ ] Server/location picker
- [ ] Profile management
- [ ] URL import
- [ ] QR import
- [ ] Clipboard import
- [ ] File import
- [ ] Subscription/profile refresh
- [ ] Settings
- [ ] Legal/privacy pages
- [ ] About page
- [ ] Account deletion flow where supported
- [ ] User-facing error states
- [ ] Offline/empty/loading states

The existing parser/builder architecture should remain reusable where platform-neutral. The HarmonyOS adapter must not fork protocol parsing unnecessarily.

## M7 — Backend integration

**Definition of done:** production server-side resources can be resolved and used without embedding private infrastructure in the public repository.

- [ ] Connect the Harmony application to the production API through the private runtime integration
- [ ] Resolve profile/subscription state
- [ ] Refresh configuration safely
- [ ] Handle expired/invalid server-side state
- [ ] Preserve the public-repository security boundary
- [ ] Verify no credentials or private endpoints are committed

## M8 — Device qualification

Every release candidate must have evidence for:

| Area | Required evidence |
| --- | --- |
| Install | HAP installs successfully |
| Permission | VPN permission/trust flow succeeds |
| TUN | TUN is created and destroyed |
| Connect | Real tunnel established |
| IPv4 | Internet traffic routed |
| IPv6 | IPv6 behavior verified |
| DNS | Resolution and leak behavior verified |
| UDP | UDP traffic verified |
| Wi-Fi | Stable tunnel |
| Cellular | Stable tunnel |
| Network switch | Recovery verified |
| Background | Stable after backgrounding |
| Screen lock | Stable after lock/unlock |
| Reconnect | Recovery verified |
| Invalid config | Fails safely |
| Endpoint failure | User-visible recovery |
| Long run | Stability evidence |

Do not mark a protocol `tested` from parser/build evidence alone.

## M9 — AppGallery release

**Definition of done:** a signed release candidate passes Huawei distribution requirements.

- [ ] Production signing configuration
- [ ] Release HAP
- [ ] App icon and branding
- [ ] AppGallery screenshots
- [ ] Store description
- [ ] Privacy policy
- [ ] Legal information
- [ ] Permission justification
- [ ] VPN functionality description
- [ ] Data/privacy declarations
- [ ] Internal release candidate
- [ ] AppGallery submission
- [ ] Review fixes
- [ ] Production publication

---

## Current execution order

1. **M1 — buildable DevEco project**
2. **M2 — real HarmonyOS TUN**
3. **M3 — real `libvpndirect_core.so`**
4. **M4 — first working VPN**
5. **M5 — network qualification**
6. **M6 — product layer**
7. **M7 — backend integration**
8. **M8 — device qualification**
9. **M9 — AppGallery**

We do not move a milestone to complete until its definition of done is actually demonstrated.

## Current Core pins

| Component | Pin |
| --- | --- |
| VPN Direct Core | `0.1.0` |
| Core name | `VPNDirectCore` |
| sing-box fork | `Leadaxe/sing-box-lx` |
| sing-box revision | `v1.14.0-lx.35` |
| upstream baseline | `1.14.0` |

## Engineering rule

When an implementation detail is uncertain, verify it against the current HarmonyOS SDK/API and a real-device build rather than inventing an API or silently substituting Android behavior.
