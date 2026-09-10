# Interop lab — hysteria (canonical)

Variants: `hysteria` (hy1), `hysteria2` plain, `hy2-salamander` (obfs), `hy2-gecko` (capability-gated).

Pin: `VERSION`. Prefer IPv4 DOCUMENTATION hosts in fixtures; note IPv6 separately in evidence.

## Run

```bash
cp .env.example .env && set -a && source .env && set +a
./run.sh
docker compose --profile lab up -d
```

Legacy: [`../../hysteria/`](../../hysteria/).
