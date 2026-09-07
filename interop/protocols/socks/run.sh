#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="${ROOT}/tests/fixtures/battle"
mkdir -p "${OUT_DIR}"
: "${BATTLE_HOST:?}"
PORT="${BATTLE_PORT:-1080}"
USER="${BATTLE_USERNAME:-}"
PASS="${BATTLE_PASSWORD:-}"
if [[ -n "${USER}" && -n "${PASS}" ]]; then
  URI="socks5://${USER}:${PASS}@${BATTLE_HOST}:${PORT}#battle-socks"
else
  URI="socks5://${BATTLE_HOST}:${PORT}#battle-socks-noauth"
fi
echo "${URI}" > "${OUT_DIR}/socks.generated.uri"
echo "wrote ${OUT_DIR}/socks.generated.uri"
