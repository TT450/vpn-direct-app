# Compatibility Harvest — TheTochka

Donor: GitHub [`TheTochka/thetochka-vpn-client`](https://github.com/TheTochka/thetochka-vpn-client) branch **`dev`** (production Remnawave/Happ/Xray behaviors). Local checkout may lag behind `dev`.

Treat TheTochka as a **golden compatibility donor**, not as architecture to copy wholesale.

## Landed in VPN Direct

| Behavior | Status |
| --- | --- |
| Happ-first subscription User-Agent | Done — `SubscriptionClientIdentity` |
| Keep app `HTTPClient` as `vpndirect/…` | Done — not Happ |
| X-HWID + device headers | Done — via identity helper |
| Stable HWID → Keychain + UserDefaults migrate | Done — `DeviceIdentity` |
| Panel stub / loopback helper | Done — `EndpointValidator` |
| `NormalizedNode.detour` field | Done |
| `NormalizedSubscription` / `NormalizedLocation` | Done |
| Hysteria / HY2 share-link + Xray conversion | Done |
| Remnawave balancers → location `urltest` | Done — `SingBoxGraphBuilder` |
| Global auto vs per-country urltest | Done — selector + `auto` over all leaves |
| Per-profile dedupe (not global) | Done — `XrayJSONAdapter` |
| `dialerProxy` → sing-box `detour` end-to-end | Done |
| Reality+XHTTP `stream-one → auto` | Done — minimal rule in `XrayVLESSConverter` |
| Regression fixtures (Remnawave / HY2 / cascade / stub) | Done — `check_subscription_graph.sh` |

## Still to harvest (later)

| Behavior | Priority |
| --- | --- |
| XHTTP extra / Yandex CDN quirks (`XHTTPTransportMapping`) | P1 |
| Clash / Mihomo YAML + remaining Universal Parser schemes | M3 |
| Interop lab / device qualification | M7–M8 |

## Rule

Do not invent new Remnawave semantics when TheTochka already fixed a TestFlight regression — port the rule, then reshape into Universal Parser.

**Universal Parser expansion (TUIC/AnyTLS/SS/…) is blocked until these harvest fixtures stay green.**
