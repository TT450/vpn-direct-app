#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIX="${ROOT}/tests/fixtures/panels/libertea"
echo "Libertea subscription export"
echo "1) bootstrap.sh install on Ubuntu 22.04; configure camouflage domain"
echo "2) Create GROUP-A / GROUP-B failover; shared primary endpoint"
echo "3) Export Clash → ${FIX}/groups_clash.yaml"
echo "4) Headers → ${FIX}/headers.json"
echo "5) Evidence → $(dirname "$0")/evidence/"
echo "Done (stub)."
