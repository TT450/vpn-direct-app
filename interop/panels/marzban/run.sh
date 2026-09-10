#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIX="${ROOT}/tests/fixtures/panels/marzban"
echo "Marzban subscription export"
echo "1) Install via Marzban-scripts; create sudo admin (marzban-cli)"
echo "2) Create user + inbounds (VLESS/VMess/Trojan/SS)"
echo "3) Copy subscription URL → curl with Clash / sing-box / link UAs"
echo "4) Write ${FIX}/uri_list.txt, clash.yaml, singbox.json, headers.json"
echo "5) Sanitize to documentation IPs; evidence → $(dirname "$0")/evidence/"
echo "Done (stub)."
