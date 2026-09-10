#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="${ROOT}/tests/fixtures/battle"
mkdir -p "${OUT_DIR}"
: "${BATTLE_HOST:?}"
: "${BATTLE_USERNAME:?}"
: "${BATTLE_PASSWORD:?}"
PORT="${BATTLE_PORT:-443}"
URI="naive+https://${BATTLE_USERNAME}:${BATTLE_PASSWORD}@${BATTLE_HOST}:${PORT}#battle-naive"
echo "${URI}" > "${OUT_DIR}/naive.generated.uri"
echo "wrote ${OUT_DIR}/naive.generated.uri"
