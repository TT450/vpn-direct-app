# Interop — AmneziaWG

## Inject battle keys

| Variable | Meaning |
| --- | --- |
| `BATTLE_PRIVATE_KEY` | Interface private key |
| `BATTLE_PEER_PUBLIC_KEY` | Peer public key |
| `BATTLE_ENDPOINT` | `host:port` |
| `BATTLE_ADDRESS` | Local address CIDR |
| `BATTLE_JC` / `BATTLE_JMIN` / `BATTLE_JMAX` | AWG junk params |
| `BATTLE_S1` / `BATTLE_S2` / `BATTLE_H1`… | AWG header params |

## Run

```bash
./run.sh
# Optional lab container is a placeholder — prefer a real Amnezia server for battles.
```

Client conf: `tests/fixtures/battle/amnezia.generated.conf`
