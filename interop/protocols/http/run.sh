#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OUT_DIR="${ROOT}/tests/fixtures/battle"
mkdir -p "${OUT_DIR}"
: "${BATTLE_HOST:?}"
PORT="${BATTLE_PORT:-8080}"
USER="${BATTLE_USERNAME:-lab}"
PASS="${BATTLE_PASSWORD:-lab-http-password}"
echo "http-proxy://${USER}:${PASS}@${BATTLE_HOST}:${PORT}#battle-http" > "${OUT_DIR}/http.generated.uri"
echo "https-proxy://${USER}:${PASS}@${BATTLE_HOST}:8443?sni=www.example.com#battle-https" >> "${OUT_DIR}/http.generated.uri"
echo "wrote ${OUT_DIR}/http.generated.uri"
