> **Canonical lab:** [`../protocols/hysteria/`](../protocols/hysteria/)

# Interop — Hysteria / Hysteria2

## Inject battle keys

| Variable | Meaning |
| --- | --- |
| `BATTLE_HOST` | Server host |
| `BATTLE_PORT` | UDP port |
| `BATTLE_PASSWORD` | HY2 password / HY1 auth |
| `BATTLE_SNI` | TLS SNI |
| `BATTLE_OBFS` | Optional obfuscation type |
| `BATTLE_OBFS_PASSWORD` | Obfuscation password |

## Run

```bash
./run.sh
docker compose --profile lab up -d
```

Expected client fixture: `tests/fixtures/battle/hysteria.generated.uri`
