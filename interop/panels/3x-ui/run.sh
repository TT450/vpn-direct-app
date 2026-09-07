#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIX="${ROOT}/tests/fixtures/panels/3x-ui"
echo "3x-ui subscription export"
echo "1) Create inbound + client in panel UI/API"
echo "2) curl -D headers.txt \"\${SUB_BASE}\${SUB_PATH}<token>\" → raw_links / base64"
echo "3) curl \"\${SUB_BASE}\${SUB_JSON_PATH}<token>\" → xray_single.json"
echo "4) curl \"\${SUB_BASE}\${SUB_CLASH_PATH}<token>\" → clash.yaml (expect reality-opts / ws-opts)"
echo "5) Sanitize hosts to 203.0.113.x; write headers into ${FIX}/headers.json"
echo "6) Evidence → $(dirname "$0")/evidence/"
echo "Done (stub)."
