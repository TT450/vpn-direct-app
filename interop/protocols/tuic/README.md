# Interop lab — tuic

Variant: **tuic-v5**. Notes: congestion control (`bbr`/`cubic`), `udp_relay_mode` (`native`/`quic`),
SNI / ALPN, optional 0-RTT. Docker image often impractical — host-install pinned `tuic-server` and
point at `configs/server.json`.

## Run

```bash
cp .env.example .env && set -a && source .env && set +a
./run.sh
# docker compose --profile lab up -d   # placeholder only
```
