#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIX="${ROOT}/tests/fixtures/panels/x-ui"
echo "x-ui subscription export"
echo "1) docker compose --profile lab up -d; create inbound + client"
echo "2) Enable subscription server; note path/token"
echo "3) curl -D headers.txt \"\${SUB_BASE}\${SUB_PATH}<token>\" → raw_links / base64"
echo "4) Sanitize hosts to 203.0.113.x; write headers into ${FIX}/headers.json"
echo "5) Diff headers/body shape vs tests/fixtures/panels/3x-ui/ (format twin, not identical)"
echo "6) Evidence → $(dirname "$0")/evidence/"
echo "Done (stub)."
