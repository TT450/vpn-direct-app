#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIX="${ROOT}/tests/fixtures/panels/marzneshin"
echo "Marzneshin subscription export"
echo "1) Install panel + marznode (Xray + HY2 backends)"
echo "2) Assign user nodes from both backends"
echo "3) Export URI list → ${FIX}/mixed_xray_hy2.txt (one vless:// + one hysteria2://)"
echo "4) Capture headers → ${FIX}/headers.json"
echo "5) Evidence → $(dirname "$0")/evidence/"
echo "Done (stub)."
