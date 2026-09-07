#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="${ROOT}/tests/fixtures/battle"
mkdir -p "${OUT_DIR}"
: "${BATTLE_HOST:?}"
: "${BATTLE_PASSWORD:?}"
PORT="${BATTLE_PORT:-443}"
SNI="${BATTLE_SNI:-www.example.com}"
URI="anytls://${BATTLE_PASSWORD}@${BATTLE_HOST}:${PORT}?sni=${SNI}#battle-anytls"
echo "${URI}" > "${OUT_DIR}/anytls.generated.uri"
echo "wrote ${OUT_DIR}/anytls.generated.uri"
