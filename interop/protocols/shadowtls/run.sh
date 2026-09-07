#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="${ROOT}/tests/fixtures/battle"
mkdir -p "${OUT_DIR}"
: "${BATTLE_HOST:?}"
: "${BATTLE_PASSWORD:?}"
PORT="${BATTLE_PORT:-443}"
SNI="${BATTLE_SNI:-www.example.com}"
URI="shadowtls://${BATTLE_PASSWORD}@${BATTLE_HOST}:${PORT}?sni=${SNI}#battle-shadowtls"
echo "${URI}" > "${OUT_DIR}/shadowtls.generated.uri"
# Also emit chained Clash snippet for manual import tests
cat > "${OUT_DIR}/shadowtls.generated.clash.yaml" <<EOF
proxies:
  - name: battle-shadowtls-ss
    type: ss
    server: ${BATTLE_HOST}
    port: ${PORT}
    cipher: ${BATTLE_SS_METHOD:-aes-256-gcm}
    password: ${BATTLE_SS_PASSWORD:-lab-ss-password}
    plugin: shadow-tls
    plugin-opts:
      host: ${SNI}
      password: ${BATTLE_PASSWORD}
EOF
echo "wrote ${OUT_DIR}/shadowtls.generated.uri (+ clash)"
