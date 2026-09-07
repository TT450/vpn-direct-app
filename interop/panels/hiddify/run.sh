#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIX="${ROOT}/tests/fixtures/panels/hiddify"
echo "Hiddify Manager subscription export"
echo "1) Install via pinned Hiddify-Manager install.sh (Ubuntu 22.04 VPS)"
echo "2) Create user; copy subscription link"
echo "3) curl -D - \"\$SUBSCRIPTION_URL\" -A \"\$USER_AGENT\""
echo "4) Save base64 body → ${FIX}/base64.txt; Clash → ${FIX}/clash.yaml"
echo "5) Persist subscription-userinfo → ${FIX}/headers.json"
echo "6) Evidence → $(dirname "$0")/evidence/"
echo "Done (stub)."
