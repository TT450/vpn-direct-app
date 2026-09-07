# tx-ui

## Pins

| Item | Value |
| --- | --- |
| Primary fork (active) | https://github.com/AghayeCoder/tx-ui |
| Alternate fork | https://github.com/Incognito-Coder/tx-ui |
| Topic index | https://github.com/topics/tx-ui |
| Install (AghayeCoder) | `bash <(curl -Ls https://raw.githubusercontent.com/AghayeCoder/tx-ui/main/install.sh)` |
| Install (Incognito-Coder) | `bash <(curl -Ls https://raw.githubusercontent.com/Incognito-Coder/tx-ui/master/install.sh)` |
| Docker (Incognito image) | `ghcr.io/incognitocoder/tx-ui:latest` |
| Pin note | Two active forks — pin **both** install script URL and image tag per lab. Do not hardcode a single upstream domain. |
| last_checked | 2026-09-07 |

## Core / backend

Direct fork of 3x-ui (Xray-core). CLI remains `x-ui` (not renamed). SSL via ACME built-in. Format of generated links/JSON ≈ **3x-ui** — parsers that already handle 3x-ui generally accept tx-ui without a separate code path, but fixtures stay separate for regression.

## Subscription formats

Same path-based model as 3x-ui: raw URI / base64, Xray JSON, Clash (when enabled). Schemes: VLESS, VMess, Trojan, SS, HY2 as configured on inbounds.

## Headers / HWID / UA

Expect 3x-ui-compatible subscription headers (`Subscription-Userinfo`, profile metadata, optional Happ Routing). HWID not standard.

## Topology notes

Single-panel Xray topology; no Remnawave Response Rules. Fork divergence may appear in UI/theme and packaging only.

## API notes (lab only)

Use whichever fork’s OpenAPI / panel API matches the pinned image. Prefer validating against **exported subscription bytes**, not admin HTML.

## Fixtures

`tests/fixtures/panels/tx-ui/` — 3x-ui-style `raw_links.txt` + `headers.json` (format twin note).

## Status

`researched` — compatibility/test target; upstream forks may carry non-prod disclaimers — do not claim `tested` without evidence.
