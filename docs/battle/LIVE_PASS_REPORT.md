# Live pass report — public sources (validate-only)

Date: **2026-09-07**  
Runner: `./scripts/battle/run_battle_tests.sh --public-only --limit-per-source 40 --validate-only --output artifacts/battle`  
Artifacts: `artifacts/battle/public-source-report.json`, `parse-summary.json`, `tests/fixtures/battle/cache/manifest.json`

## Scope (honest)

- **Done:** catalog check, HTTPS fetch of intentional public pools, BattleParse parse/build/core_validation on cached bodies.
- **Not done:** Network Extension / device live connect. **No connect SUCCESS claimed.**
- `--limit-per-source 40` caps returned nodes used for builder/core tallies; BattleParse `diagnostics.*` still reflect full-file entry classification.

## Fetch

| Metric | Count |
| --- | --- |
| Sources attempted | 24 |
| OK | 24 |
| SOURCE_FETCH_FAILED | 0 |
| SOURCE_EMPTY | 0 |

## Parse (per source)

| Metric | Count |
| --- | --- |
| Sources parsed | 24 |
| OK | 24 |
| PARSE_FAILED | 0 |
| not_run | 0 |
| skipped | 0 |

All 24 catalog sources: fetch **OK** + parse **OK**. `last_verified` set to `2026-09-07` in `tests/battle/public-sources.json`.

## Entries (BattleParse diagnostics — full files)

| Metric | Count |
| --- | --- |
| total | 113940 |
| parsed | 105200 |
| unsupported | 3733 |
| malformed | 5007 |

## Builder / core_validation (limited nodes only, limit=40/source)

| Metric | Count |
| --- | --- |
| nodes returned | 847 |
| builder ok | 695 |
| builder failures | 152 |
| core_validation ok | 681 |
| core_validation error | 14 |
| core_validation not_run (usually after builder error) | 152 |

## Live connect

| Metric | Value |
| --- | --- |
| Attempted | 0 |
| SUCCESS | 0 |
| FAIL | 0 |

`--validate-only` skipped connect. Public remote liveness was not measured (`remote_server_dead` would apply to many free pools).

## Protocols still requiring own live server

Public pools are **parser stress** only. Own interop / lab / paid endpoint required for honest connect evidence:

- vless (all transports / Reality / Vision / xhttp)
- vmess
- trojan
- shadowsocks / shadowsocks-2022
- hysteria / hysteria2 (incl. salamander / gecko)
- tuic-v5
- anytls
- shadowtls
- naive
- wireguard / AmneziaWG
- mieru
- socks / http(s) proxy / ssh
- masque-connect-ip

## External credentials still required

- WARP / Cloudflare live: WARP_PROFILE_PATH or WARP_* key env vars (see EXTERNAL_CREDENTIALS.md)
- Protocol lab: BATTLE_UUID / BATTLE_PASSWORD / Reality BATTLE_PBK/SID/SNI / BATTLE_WG_* / MIERU_* under interop/protocols/*/ .env
- Device: BATTLE_DEVICE_ID / BATTLE_CORE_SHA for iPhone qualification

Public catalog HTTPS GETs need **no** credentials.

## Coverage note

`docs/battle/BATTLE_COVERAGE.md` Public sources column updated to `pass` where this run had OK fetch+parse for that family/variant. **Live public** remains `planned` / `n/a` / `external` — connect not executed.
