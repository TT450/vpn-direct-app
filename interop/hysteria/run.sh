#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="${ROOT}/tests/fixtures/battle"
mkdir -p "${OUT_DIR}"
: "${BATTLE_HOST:?set BATTLE_HOST}"
: "${BATTLE_PASSWORD:?set BATTLE_PASSWORD}"
PORT="${BATTLE_PORT:-443}"
SNI="${BATTLE_SNI:-www.example.com}"
URI="hysteria2://${BATTLE_PASSWORD}@${BATTLE_HOST}:${PORT}?sni=${SNI}&insecure=0#battle-hy2"
echo "${URI}" > "${OUT_DIR}/hysteria.generated.uri"
echo "wrote ${OUT_DIR}/hysteria.generated.uri"
