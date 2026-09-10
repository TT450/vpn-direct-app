#!/usr/bin/env bash
# Compile-time / unit proofs for VPN Direct capability tags.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${ROOT}/core/sing-box"
OVERLAY="${ROOT}/core/overlays/libbox"

fail=0

# Ensure mieru overlays before probing Core sources.
bash "${ROOT}/scripts/prepare_core.sh" || fail=1


assert_mieru_tag_on() {
  local f="$1"
  if [[ ! -f "${f}" ]]; then
    echo "MISSING tags file ${f}" >&2
    fail=1
    return
  fi
  if ! grep -q 'with_mieru' "${f}"; then
    echo "ERROR ${f} missing with_mieru (runtime is ported)" >&2
    fail=1
  else
    echo "OK with_mieru in $(basename "${f}")"
  fi
}

if [[ ! -f "${CORE}/protocol/mieru/outbound.go" ]] || [[ ! -f "${CORE}/include/mieru.go" ]]; then
  echo "ERROR mieru runtime missing under core/sing-box" >&2
  fail=1
else
  echo "OK mieru runtime sources present"
fi

assert_mieru_tag_on "${ROOT}/scripts/tags/vpn_direct_ios.tags"
assert_mieru_tag_on "${ROOT}/scripts/tags/vpn_direct_full.tags"

if [[ ! -d "${CORE}/experimental/libbox" ]]; then
  echo "note: core/sing-box missing — skipping Go capability tests"
  if [[ "${fail}" -ne 0 ]]; then
    exit 1
  fi
  exit 0
fi

cp -f "${OVERLAY}"/*.go "${CORE}/experimental/libbox/"

TAGS='with_gvisor,with_quic,with_wireguard,with_utls,with_xhttp,with_awg,with_lx_idle_suspend,with_mieru'
set +e
(
  cd "${CORE}"
  go test ./experimental/libbox -count=1 -run 'TestVPNDirectCapability' -tags "${TAGS}" \
    >/tmp/vpndirect-capability-proofs.log 2>&1
)
status=$?
set -e

if [[ "${status}" -eq 0 ]]; then
  echo "OK go test capability proofs"
else
  echo "ERROR capability proofs failed" >&2
  tail -50 /tmp/vpndirect-capability-proofs.log || true
  fail=1
fi

if [[ "${fail}" -ne 0 ]]; then
  echo "check_capability_proofs FAILED" >&2
  exit 1
fi
echo "check_capability_proofs OK"
