# Compatibility Harvest — TheTochka

Donor: GitHub [`TheTochka/thetochka-vpn-client`](https://github.com/TheTochka/thetochka-vpn-client) branch **`dev`** (production Remnawave/Happ/Xray behaviors). Local checkout may lag behind `dev`.

Treat TheTochka as a **golden compatibility donor**, not as architecture to copy wholesale.

## Landed in VPN Direct (this tranche)

| Behavior | Status |
| --- | --- |
| Happ-first subscription User-Agent | Done — `SubscriptionClientIdentity` |
| Keep app `HTTPClient` as `vpndirect/…` | Done — not Happ |
| X-HWID + device headers | Done — via identity helper |
| Stable HWID → Keychain + UserDefaults migrate | Done — `DeviceIdentity` |
| Panel stub / loopback helper | Done — `EndpointValidator` skeleton |
| `NormalizedNode.detour` field | Done — model hook for dialerProxy |

## Still to harvest (next milestones)

| Behavior | Priority |
| --- | --- |
| Hysteria / HY2 share-link + Xray conversion | P0 |
| Remnawave balancers → location `urltest` (Happ-style) | P0 |
| Global auto vs per-country urltest | P0 |
| Per-profile dedupe (not global) | P0 |
| `dialerProxy` → sing-box `detour` | P1 |
| XHTTP extra / Yandex CDN quirks | P1 |
| Reality+XHTTP stream-one → auto | P1 |
| NormalizedLocation / NormalizedEndpoint split | P1 |

## Rule

Do not invent new Remnawave semantics when TheTochka already fixed a TestFlight regression — port the rule, then reshape into Universal Parser.
