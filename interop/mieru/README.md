> **Canonical lab:** [`../protocols/mieru/`](../protocols/mieru/)

# Interop — Mieru (mita)

Requires Core built with `with_mieru` (enabled in `scripts/tags/vpn_direct_*.tags` as of v1.0.6).

## Inject battle keys

| Variable | Meaning |
| --- | --- |
| `BATTLE_HOST` | mita server host |
| `BATTLE_PORT` | port |
| `BATTLE_USERNAME` | user |
| `BATTLE_PASSWORD` | password |
| `BATTLE_TRANSPORT` | `TCP` or `UDP` (default TCP) |
| `BATTLE_TRAFFIC_PATTERN` | optional low-entropy / traffic_pattern string |
| `BATTLE_MULTIPLEXING` | optional multiplexing level enum string |

## Run

```bash
./run.sh
docker compose --profile lab up -d   # optional local mita if image available
```

Client JSON: `tests/fixtures/battle/mieru.generated.json` — import via Mieru profile path / paste.

## Evidence

Leave `evidence/` empty until live mita handshake + DNS + reconnect are proven on device.
