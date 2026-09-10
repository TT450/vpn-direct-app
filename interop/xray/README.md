> **Canonical lab:** [`../protocols/xray/`](../protocols/xray/)

# Interop — xray (VLESS Reality / VMess / Trojan)

## Inject battle keys (env)

| Variable | Meaning |
| --- | --- |
| `BATTLE_UUID` | VLESS/VMess UUID |
| `BATTLE_PASSWORD` | Trojan password |
| `BATTLE_PBK` | Reality public key |
| `BATTLE_SID` | Reality short id |
| `BATTLE_SNI` | TLS/Reality server name |
| `BATTLE_HOST` | Server host/IP |
| `BATTLE_PORT` | Server port (default 443) |
| `BATTLE_PATH` | WS path (default `/`) |

## Run

```bash
./run.sh                 # renders client fixture → prints path
docker compose up -d     # optional local xray reference (sanitized)
```

Client fixture output: `../../tests/fixtures/battle/xray.generated.uri` (gitignored pattern under `battle/`).

## Exit criteria

Handshake, TCP/(UDP), DNS, reconnect. Do not mark PROTOCOL_MATRIX `tested` until evidence is attached under `evidence/`.
