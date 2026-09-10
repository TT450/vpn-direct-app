#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIX="${ROOT}/tests/fixtures/panels/s-ui"
echo "s-ui subscription export"
echo "1) docker compose --profile lab up -d; change admin/admin"
echo "2) Create inbound + client; enable JSON subscription"
echo "3) Export sing-box JSON → ${FIX}/singbox.json"
echo "4) Headers → ${FIX}/headers.json"
echo "5) Optional: token API (1.2.0+) for automation"
echo "6) Evidence → $(dirname "$0")/evidence/"
echo "Done (stub)."
