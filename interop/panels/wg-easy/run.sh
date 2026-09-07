#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIX="${ROOT}/tests/fixtures/panels/wg-easy"
echo "wg-easy WireGuard .conf export"
echo "1) Set WG_HOST + PASSWORD in .env; docker compose --profile lab up -d"
echo "2) Open \${PANEL_URL}; create a peer"
echo "3) Download peer .conf → ${FIX}/wireguard_peer.conf"
echo "4) Sanitize Endpoint/AllowedIPs to lab values (e.g. 203.0.113.x)"
echo "5) headers.json stub (N/A for conf download) → ${FIX}/headers.json"
echo "6) Evidence → $(dirname "$0")/evidence/"
echo "Done (stub)."
