# s-ui

## Pins

| Item | Value |
| --- | --- |
| Repo | https://github.com/alireza0/s-ui |
| API wiki (fork mirror) | https://github.com/vchan-ui/s-ui/wiki/API-Documentation |
| Releases | https://github.com/alireza0/s-ui/releases |
| Install | `bash <(curl -Ls https://raw.githubusercontent.com/alireza0/s-ui/master/install.sh)` |
| Docker image | `alireza7/s-ui:latest` |
| Default ports | Panel `2095` (`/app/`), subscription `2096` (`/sub/`); default login `admin`/`admin` |
| Pin note | From 1.2.0 sing-box is **embedded** — panel version pins core version (e.g. 1.2.0 → sing-box v1.11.0). Pin release tag. |
| last_checked | 2026-09-07 |

## Core / backend

sing-box panel (same engine family as VPN Direct Core). Closest “native” panel for Core integration testing. Token API from 1.2.0+. Windows amd64 zip available for local labs.

## Subscription formats

link / JSON / Clash generation. Primary fixture: full minimal **sing-box JSON** with one outbound.

## Headers / HWID / UA

`Subscription-Userinfo`, update-interval when enabled. Format may follow UA. HWID not standard Remnawave-style.

## Topology notes

Single outbound sing-box configs are baseline; expand to multi-outbound when lab needs selector/urltest.

## API notes (lab only)

Token API for users/inbounds without HTML scraping. Docker Compose from upstream `docker-compose.yml`. Export subscription body for fixtures.

## Fixtures

`tests/fixtures/panels/s-ui/` — `singbox.json`, `headers.json`.

## Status

`researched` — fixtures present; not `tested`.
