# x-ui

## Pins

| Item | Value |
| --- | --- |
| Repo | https://github.com/alireza0/x-ui |
| Pin note | Upstream of the x-ui family; prefer tagged releases. Do **not** assume wire-identical subscription headers to MHSanaei/3x-ui without fixture diff. |
| last_checked | 2026-09-07 |

## Core / backend

Xray-core web panel (alireza0). Historical predecessor / sibling to 3x-ui; UI and sub server evolved separately.

## Subscription formats

URI list (raw or base64) and optional JSON/Clash-style exports depending on build. Treat format as **≈ 3x-ui twin** for parser targeting, but keep separate fixtures so header/path drift is detectable.

## Headers / HWID / UA

Expect Clash/V2RayNG-style headers when enabled: `Subscription-Userinfo`, `Profile-Update-Interval`, optional `Profile-Title`. HWID not standard. Confirm with live lab headers before fingerprinting as `3x-ui`.

## Topology notes

Typically single-node inbound → client subscription. No Remnawave-style Response Rules.

## API notes (lab only)

Panel web/API for inbound CRUD; lab export via subscription URL. See `tests/fixtures/panels/x-ui/` (adapted 3x-ui-style corpus).

## Fixtures

`tests/fixtures/panels/x-ui/` — `raw_links.txt`, `headers.json` (format twin of 3x-ui).

## Status

`researched` — fixtures present; do not claim ≡ 3x-ui in product matrix without evidence.
