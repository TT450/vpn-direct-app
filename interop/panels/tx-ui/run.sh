#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIX="${ROOT}/tests/fixtures/panels/tx-ui"
echo "tx-ui subscription export"
echo "1) Pin FORK in .env (AghayeCoder install.sh or Incognito docker compose --profile lab up -d)"
echo "2) Create inbound + client (CLI remains x-ui)"
echo "3) curl -D headers.txt \"\${SUB_BASE}\${SUB_PATH}<token>\" → raw_links / base64"
echo "4) curl \"\${SUB_BASE}\${SUB_JSON_PATH}<token>\" → xray JSON; Clash via SUB_CLASH_PATH"
echo "5) Sanitize hosts to 203.0.113.x; write headers into ${FIX}/headers.json"
echo "6) Evidence → $(dirname "$0")/evidence/"
echo "Done (stub)."
