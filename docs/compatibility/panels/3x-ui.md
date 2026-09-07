# 3x-ui

## Pins

| Item | Value |
| --- | --- |
| Repo | https://github.com/MHSanaei/3x-ui |
| Subscription docs | `docs/content/docs/en/config/subscription.mdx` (main) |
| OpenAPI | `docs/public/openapi.json` |
| Headers implementation | `sub/subController.go` `ApplyCommonHeaders` |
| Pin note | Track latest release tag on MHSanaei/3x-ui; subscription path toggles vary by version. |
| last_checked | 2026-09-07 |

## Core / backend

Xray-core panel (inbound/client management). Product marketing may mention WG / Hysteria / AmneziaWG / multi-node / balancers — verify against the pinned release before claiming support.

## Subscription formats

Separate subscription server (`subEnable`, default port **2096**). Formats selected by **path** toggles:

| Format | Toggle |
| --- | --- |
| Raw / base64 URI list | `subPath` / `subEncrypt` |
| Xray JSON | `subJsonPath` / `subJsonEnable` |
| Clash | `subClashPath` / `subClashEnable` |

Typical URI schemes in raw/base64: VLESS, VMess, Trojan, Shadowsocks, Hysteria2 (when inbound type exists).

## Headers / HWID / UA

**Response headers (ApplyCommonHeaders):** `Subscription-Userinfo`, `Profile-Update-Interval`, `Profile-Title` (`base64:` prefix), `Support-Url`, `Profile-Web-Page-Url`, `Announce` (`base64:`), Happ `Routing` / `Routing-Enable`. HEAD supported on sub endpoints (traffic peek).

HWID device binding is **not** a first-class 3x-ui subscription feature (unlike Remnawave); treat as absent unless a custom fork adds it.

## Topology notes

Single-server oriented by default; multi-node / balancer features are release-dependent. Clash export may include `reality-opts` and `ws-opts` nested maps — parsers must not flatten-drop them.

## API notes (lab only)

OpenAPI present — use for lab automation (create inbound/client, fetch sub URL) in `interop/panels/3x-ui/`. Not for iOS runtime.

## Fixtures

`tests/fixtures/panels/3x-ui/` — headers (incl. Routing), raw_links, base64, xray_single, clash with reality/ws opts.

## Status

`researched` — fixture corpus present; `fixture_pass` / `tested` pending executable checks + evidence.
