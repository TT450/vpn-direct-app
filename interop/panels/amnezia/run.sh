#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIX="${ROOT}/tests/fixtures/panels/amnezia"
echo "Amnezia AWG conf export"
echo "1) Prefer official Amnezia client → deploy AmneziaWG on disposable VPS"
echo "   OR: docker compose --profile lab up -d (community amnezia-wg-easy)"
echo "2) Create peer/user; export AmneziaWG .conf (Jc/Jmin/Jmax/S*/H*)"
echo "3) Save → ${FIX}/awg2_sample.conf (sanitize Endpoint to 203.0.113.x)"
echo "4) headers.json stub (N/A for conf) → ${FIX}/headers.json"
echo "5) Evidence → $(dirname "$0")/evidence/"
echo "Done (stub)."
