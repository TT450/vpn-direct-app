#!/usr/bin/env bash
# Remnawave lab: echo export steps (no live secrets).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FIX="${ROOT}/tests/fixtures/panels/remnawave"
echo "Remnawave subscription export"
echo "1) Set PANEL_URL / ADMIN_TOKEN / SUBSCRIPTION_URL in .env (from .env.example)"
echo "2) Request with Happ UA + x-hwid header matching panel HWID policy"
echo "3) Capture Response Rules bodies:"
echo "   - XRAY_JSON  → ${FIX}/xray_json_locations.json"
echo "   - XRAY_BASE64 → ${FIX}/xray_base64.txt"
echo "   - CLASH      → ${FIX}/clash_sample.yaml"
echo "   - HWID block headers → ${FIX}/hwid_blocked_headers.json"
echo "4) Sanitize to 203.0.113.x / fixture UUIDs before commit"
echo "5) Drop redacted evidence under $(dirname "$0")/evidence/"
echo "Done (stub). Wire curl/API once PANEL_URL is set."
