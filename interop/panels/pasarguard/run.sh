#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIX="${ROOT}/tests/fixtures/panels/pasarguard"
echo "PasarGuard subscription export"
echo "1) Install via pasarguard.sh; pasarguard cli generate-temp-key → owner"
echo "2) Enable Xray + WireGuard cores for a user"
echo "3) Export → ${FIX}/uri_list.txt (vless + wireguard)"
echo "4) Headers (incl. any HWID) → ${FIX}/headers.json"
echo "5) Evidence → $(dirname "$0")/evidence/"
echo "Done (stub)."
