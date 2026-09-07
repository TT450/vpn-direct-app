# Interop lab — wireguard

wg-easy style panel + peer `.conf`. Cover IPv4/IPv6, optional PSK, MTU, DNS, keepalive.

## Run

```bash
cp .env.example .env && set -a && source .env && set +a
./run.sh
docker compose --profile lab up -d
```
