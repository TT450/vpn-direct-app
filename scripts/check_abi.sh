#!/usr/bin/env bash
# ABI smoke: overlays applied + (optional) linked Libbox exports.
# Uses POSIX/BSD grep only — no ripgrep dependency (CI macOS runners).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${ROOT}/core/sing-box"
OVERLAY="${ROOT}/core/overlays/libbox"
FRAMEWORK="${ROOT}/Libbox.xcframework"

fail=0

require_overlay() {
  local f="$1"
  if [[ ! -f "${OVERLAY}/${f}" ]]; then
    echo "MISSING overlay ${f}" >&2
    fail=1
  else
    echo "OK overlay ${f}"
  fi
}

require_overlay "vpndirect_capabilities.go"
require_overlay "vpndirect_tag_gecko.go"

CAPABILITIES_FILE="${OVERLAY}/vpndirect_capabilities.go"

if ! grep -q 'VPN_DIRECT_CORE' "${CAPABILITIES_FILE}"; then
  echo "MISSING magic constant" >&2
  fail=1
else
  echo "OK magic constant"
fi
if ! grep -q 'VPNDirectCapabilityJSON' "${CAPABILITIES_FILE}"; then
  echo "MISSING CapabilityJSON" >&2
  fail=1
else
  echo "OK CapabilityJSON"
fi
if ! grep -q 'VPNDirectCoreAPIVersion' "${CAPABILITIES_FILE}"; then
  echo "MISSING APIVersion" >&2
  fail=1
else
  echo "OK APIVersion"
fi

# If framework exists, prefer header + nm smoke for magic
if [[ -d "${FRAMEWORK}" ]]; then
  HEADER="$(find "${FRAMEWORK}" -name 'Libbox.objc.h' 2>/dev/null | head -1 || true)"
  if [[ -n "${HEADER}" ]] && grep -q 'LibboxVPNDirectCoreMagic' "${HEADER}"; then
    echo "OK framework header LibboxVPNDirectCoreMagic"
  else
    echo "WARN framework header missing LibboxVPNDirectCoreMagic"
  fi
  BIN="$(find "${FRAMEWORK}/ios-arm64" -type f -name 'Libbox' 2>/dev/null | head -1 || true)"
  if [[ -z "${BIN}" ]]; then
    BIN="$(find "${FRAMEWORK}" -type f -name 'Libbox' 2>/dev/null | head -1 || true)"
  fi
  if [[ -n "${BIN}" ]]; then
    if nm "${BIN}" 2>/dev/null | grep -q 'VPNDirectCoreMagic'; then
      echo "OK framework nm VPNDirectCoreMagic"
    else
      echo "WARN framework nm missing VPNDirectCoreMagic"
    fi
    if [[ -f "${FRAMEWORK}/VPNDirectCore.version" ]]; then
      echo "OK stamp present"
      if grep -q '^SING_BOX_SHA=' "${FRAMEWORK}/VPNDirectCore.version"; then
        echo "OK stamp SING_BOX_SHA"
      else
        echo "WARN stamp missing SING_BOX_SHA"
      fi
    fi
  fi
else
  echo "note: Libbox.xcframework not present — overlay-only ABI check"
fi

# Compile-check Go overlays against donor package when submodule present.
# Compile failure must fail this script (not WARN-and-continue).
if [[ -d "${CORE}/experimental/libbox" ]]; then
  cp -f "${OVERLAY}"/*.go "${CORE}/experimental/libbox/"
  set +e
  (
    cd "${CORE}"
    go test -c -o /dev/null ./experimental/libbox \
      -tags 'with_gvisor,with_quic,with_wireguard,with_utls,with_xhttp,with_awg' \
      >/tmp/vpndirect-libbox-abi-test.log 2>&1
  )
  go_status=$?
  set -e
  if [[ "${go_status}" -eq 0 ]]; then
    echo "OK go test -c experimental/libbox"
  else
    echo "ERROR go test -c experimental/libbox failed (exit ${go_status})" >&2
    tail -40 /tmp/vpndirect-libbox-abi-test.log || true
    fail=1
  fi
fi

if [[ "${fail}" -ne 0 ]]; then
  echo "check_abi FAILED" >&2
  exit 1
fi
echo "check_abi OK"
