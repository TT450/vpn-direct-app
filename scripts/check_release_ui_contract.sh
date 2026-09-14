#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0

# The submitted product no longer exposes Free/Premium as user-facing access modes.
# Keep internal compatibility identifiers if required by migration/backend code, but do
# not allow the old labels back into active iOS UI sources.
UI_ROOT="${ROOT}/ApplicationLibrary/Views"
for needle in \
  'VPN DIRECT FREE' \
  'VPN DIRECT PREMIUM' \
  'Plus рекомендуем' \
  'PLUS.*Тарифы VPN Direct'; do
  if grep -RInE --exclude-dir=.git --exclude='*.md' -- "$needle" "$UI_ROOT" >/tmp/vpndirect-release-ui-contract.$$ 2>/dev/null; then
    echo "FORBIDDEN USER-FACING LEGACY ACCESS LABEL: $needle" >&2
    cat /tmp/vpndirect-release-ui-contract.$$ >&2
    fail=1
  fi
done
rm -f /tmp/vpndirect-release-ui-contract.$$

# Keep the release documentation internally consistent with the current candidate.
grep -q '1\.0\.11' "${ROOT}/WHATS_NEW.md" || { echo 'WHATS_NEW missing 1.0.11' >&2; fail=1; }
grep -q '\b111\b' "${ROOT}/WHATS_NEW.md" || { echo 'WHATS_NEW missing build 111' >&2; fail=1; }
grep -q '1\.0\.11' "${ROOT}/docs/TESTFLIGHT.md" || { echo 'TESTFLIGHT missing 1.0.11' >&2; fail=1; }
grep -q '\b111\b' "${ROOT}/docs/TESTFLIGHT.md" || { echo 'TESTFLIGHT missing build 111' >&2; fail=1; }

if [[ "$fail" -ne 0 ]]; then
  echo 'check_release_ui_contract FAILED' >&2
  exit 1
fi

echo 'check_release_ui_contract OK'
