# Hiddify Manager

## Pins

| Item | Value |
| --- | --- |
| Repo | https://github.com/hiddify/Hiddify-Manager |
| Wiki | https://github.com/hiddify/Hiddify-Manager/wiki |
| Quick install (Ubuntu) | https://github.com/hiddify/Hiddify-Manager/wiki/Quick-installation-on-Ubuntu |
| Org | https://github.com/hiddify |
| Site | https://hiddify.com |
| Install (example) | `bash -c "$(curl -sSL https://raw.githubusercontent.com/hiddify/Hiddify-Manager/main/common/install.sh)" -- --lang=ru` |
| Alt | `curl i.hiddify.com/release \| bash` (with `CREATE_EASYSETUP_LINK`) |
| Pin note | Install scripts change often — pin commit SHA of `install.sh` / release tag; do not hardcode install one-liners in automation without re-check. |
| last_checked | 2026-09-07 |

## Core / backend

Manages **Xray-core and sing-box** together — broad protocol surface (REALITY, Trojan, Shadowsocks, 17+ others claimed). Smart proxy for Hiddify / Clash clients. Xray project historically recommended Hiddify as an X-UI replacement.

## Subscription formats

Base64 URI lists, Clash YAML, sing-box JSON, and client-specific templates. Format often selected by User-Agent / path.

## Headers / HWID / UA

Emits **`subscription-userinfo`** (traffic/expire) — de-facto standard later adopted by many panels. Also profile update / title style headers depending on template. Capture case variants (`Subscription-Userinfo` vs `subscription-userinfo`) in fixtures.

## Topology notes

Smart proxy / domain grouping may produce Clash groups that share endpoints. Reality SNI selection tooling exists in sibling repos (Hiddify-Reality-Scanner) — lab-only.

## API notes (lab only)

Prefer panel UI export / subscription URL for fixtures. Automate carefully — install surface is large and host-invasive.

## Fixtures

`tests/fixtures/panels/hiddify/` — `base64.txt`, `clash.yaml`, `headers.json` with `subscription-userinfo`.

## Status

`researched` — fixtures present; not `tested`.
