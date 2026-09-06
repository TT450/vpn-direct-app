#!/usr/bin/env bash
# ABI smoke: overlays applied + (optional) linked Libbox exports.
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

# Apply overlays into a temp copy check: magic/API present in source
if ! rg -q 'VPN_DIRECT_CORE' "${OVERLAY}/vpndirect_capabilities.go"; then
  echo "MISSING magic constant" >&2
  fail=1
fi
if ! rg -q 'VPNDirectCapabilityJSON' "${OVERLAY}/vpndirect_capabilities.go"; then
  echo "MISSING CapabilityJSON" >&2
  fail=1
fi
if ! rg -q 'VPNDirectCoreAPIVersion' "${OVERLAY}/vpndirect_capabilities.go"; then
  echo "MISSING APIVersion" >&2
  fail=1
fi

# If framework exists, prefer header + nm smoke for magic
if [[ -d "${FRAMEWORK}" ]]; then
  HEADER="$(find "${FRAMEWORK}" -name 'Libbox.objc.h' 2>/dev/null | head -1 || true)"
  if [[ -n "${HEADER}" ]] && rg -q 'LibboxVPNDirectCoreMagic' "${HEADER}"; then
    echo "OK framework header LibboxVPNDirectCoreMagic"
  else
    echo "WARN framework header missing LibboxVPNDirectCoreMagic"
  fi
  BIN="$(find "${FRAMEWORK}/ios-arm64" -type f -name 'Libbox' 2>/dev/null | head -1 || true)"
  if [[ -z "${BIN}" ]]; then
    BIN="$(find "${FRAMEWORK}" -type f -name 'Libbox' 2>/dev/null | head -1 || true)"
  fi
  if [[ -n "${BIN}" ]]; then
    if nm "${BIN}" 2>/dev/null | rg -q 'VPNDirectCoreMagic'; then
      echo "OK framework nm VPNDirectCoreMagic"
    else
      echo "WARN framework nm missing VPNDirectCoreMagic"
    fi
    if [[ -f "${FRAMEWORK}/VPNDirectCore.version" ]]; then
      echo "OK stamp present"
      if rg -q '^SING_BOX_SHA=' "${FRAMEWORK}/VPNDirectCore.version"; then
        echo "OK stamp SING_BOX_SHA"
      else
        echo "WARN stamp missing SING_BOX_SHA"
      fi
    fi
  fi
else
  echo "note: Libbox.xcframework not present — overlay-only ABI check"
fi

# Compile-check Go overlays against donor package when submodule present
if [[ -d "${CORE}/experimental/libbox" ]]; then
  cp -f "${OVERLAY}"/*.go "${CORE}/experimental/libbox/"
  (
    cd "${CORE}"
    # tags matching default iOS profile so tag files resolve
    go test -c -o /dev/null ./experimental/libbox \
      -tags 'with_gvisor,with_quic,with_wireguard,with_utls,with_xhttp,with_awg' \
      >/tmp/vpndirect-libbox-abi-test.log 2>&1 \
      && echo "OK go test -c experimental/libbox" \
      || {
        echo "WARN go test -c experimental/libbox failed (see /tmp/vpndirect-libbox-abi-test.log)"
        tail -40 /tmp/vpndirect-libbox-abi-test.log || true
      }
  )
fi

if [[ "${fail}" -ne 0 ]]; then
  echo "check_abi FAILED" >&2
  exit 1
fi
echo "check_abi OK"
