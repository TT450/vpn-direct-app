#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT_DIR="${ROOT}/tests/fixtures/battle"
mkdir -p "${OUT_DIR}"
: "${BATTLE_HOST:?set BATTLE_HOST}"
: "${BATTLE_UUID:?set BATTLE_UUID}"
PORT="${BATTLE_PORT:-443}"
SNI="${BATTLE_SNI:-www.example.com}"
PBK="${BATTLE_PBK:-}"
SID="${BATTLE_SID:-}"
PATH_WS="${BATTLE_PATH:-/}"

URI="vless://${BATTLE_UUID}@${BATTLE_HOST}:${PORT}?encryption=none&security=reality&sni=${SNI}&fp=chrome&pbk=${PBK}&sid=${SID}&type=ws&path=${PATH_WS}#battle-xray"
echo "${URI}" > "${OUT_DIR}/xray.generated.uri"
echo "wrote ${OUT_DIR}/xray.generated.uri"
echo "Import that URI in the app (or paste into subscription). Run live traffic, then fill evidence/."
