# Interop lab — xray (canonical)

Variants: `vless-tcp`, `vless-tls`, `vless-reality`, `vless-vision`, `vless-ws`,
`vless-grpc`, `vless-httpupgrade`, `vless-xhttp`, `vless-xhttp-reality`, `vmess`,
`trojan`, `shadowsocks` (+ SS2022 via method).

Pin: see `VERSION`. Config stubs under `configs/` use DOCUMENTATION IPs (`203.0.113.x`).

## Run

```bash
cp .env.example .env
set -a; source .env; set +a
./run.sh
docker compose --profile lab up -d
./healthcheck.sh
```

Client fixture: `tests/fixtures/battle/xray.generated.uri`

Legacy path: [`../../xray/`](../../xray/) — prefer this directory.
