# Interop lab — naive

Caddy-style HTTPS / HTTP2 NaiveProxy. QUIC (`naive+quic`) is optional and may need a different
listener. Prefer host Caddy with forwardproxy module over a random Docker image.

## Run

```bash
cp .env.example .env && set -a && source .env && set +a
./run.sh
```
