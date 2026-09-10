# External credentials (battle / device)

Never commit secrets. Inject via env files that are gitignored (`.env`, `.env.*`).

## WARP / Cloudflare

| Variable | Purpose |
| --- | --- |
| `WARP_PRIVATE_KEY` | WireGuard/MASQUE private key |
| `WARP_PEER_PUBLIC_KEY` | Peer public key |
| `WARP_ENDPOINT` | Endpoint host:port |
| `WARP_LOCAL_ADDRESS` | Client tunnel addresses |
| `WARP_MTU` | Optional MTU |
| `WARP_PIN` / profile path | Prefer file: `WARP_PROFILE_PATH=/path/to/profile.json` |

Public WARP config pools (e.g. Delta-Kronecker/WARP-Config) are for **parser stress** only. Live Cloudflare connectivity is external qualification.

```bash
export WARP_PROFILE_PATH="$HOME/.config/vpndirect/warp.profile.json"
./scripts/battle/run_battle_tests.sh --local-lab --protocol warp --connect
```

## Device / iPhone

| Variable | Purpose |
| --- | --- |
| `BATTLE_DEVICE_ID` | `devicectl` identifier |
| `BATTLE_CORE_SHA` | Core / app build under test |

Fill [`docs/device/IPHONE_QUALIFICATION.md`](../device/IPHONE_QUALIFICATION.md) and emit JSON matching [`interop/evidence/SCHEMA.json`](../../interop/evidence/SCHEMA.json). Do not invent RSS numbers.

## Protocol lab keys

Per-family `.env.example` under `interop/protocols/<family>/`:

| Prefix | Families |
| --- | --- |
| `BATTLE_UUID` / `BATTLE_PASSWORD` | xray, tuic, anytls, naive, ssh |
| `BATTLE_PBK` / `BATTLE_SID` / `BATTLE_SNI` | Reality |
| `BATTLE_WG_*` | wireguard / amneziawg |
| `MIERU_*` | mieru / mita |

Copy `.env.example` → `.env` before `docker compose --profile lab up`.

## Public battle fetch

No credentials required for catalog HTTPS GETs. Do not attach Authorization headers to intentional public pools.
