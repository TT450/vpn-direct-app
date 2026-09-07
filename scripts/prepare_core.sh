#!/usr/bin/env bash
# Canonical Core tree preparation for VPN Direct.
# Idempotent, clean-clone safe, fail-closed.
#
# Usage:
#   scripts/prepare_core.sh           # require exact SING_BOX_REV, apply overlays, verify
#   scripts/prepare_core.sh --verify  # verify only (fail if overlays missing)
#   scripts/prepare_core.sh --reset   # hard-reset submodule to VERSION pin, then apply
#   scripts/prepare_core.sh --apply-dirty  # apply overlays without pin checkout (dev only)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CORE="${ROOT}/core/sing-box"
VERSION_FILE="${ROOT}/core/VERSION"
MODE="apply"

for arg in "$@"; do
  case "${arg}" in
    --verify) MODE="verify" ;;
    --reset) MODE="reset" ;;
    --apply-dirty) MODE="apply-dirty" ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
  esac
done

load_version() {
  if [[ ! -f "${VERSION_FILE}" ]]; then
    echo "error: missing ${VERSION_FILE}" >&2
    exit 1
  fi
  # shellcheck disable=SC1090
  while IFS= read -r line || [[ -n "${line}" ]]; do
    [[ -z "${line}" || "${line}" =~ ^# ]] && continue
    if [[ "${line}" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
      export "${line?}"
    fi
  done < "${VERSION_FILE}"
}

resolve_pin_commit() {
  local pin="${1:?}"
  (
    cd "${CORE}"
    if git rev-parse --verify "${pin}^{commit}" >/dev/null 2>&1; then
      git rev-parse "${pin}^{commit}"
    elif git rev-parse --verify "tags/${pin}" >/dev/null 2>&1; then
      git rev-parse "tags/${pin}^{commit}"
    else
      echo ""
    fi
  )
}

ensure_exact_pin() {
  local pin="${SING_BOX_REV:-}"
  if [[ -z "${pin}" ]]; then
    echo "error: SING_BOX_REV missing from ${VERSION_FILE}" >&2
    exit 1
  fi
  local want
  want="$(resolve_pin_commit "${pin}")"
  if [[ -z "${want}" ]]; then
    echo "prepare_core: fetching tags to resolve pin ${pin}"
    (
      cd "${CORE}"
      git fetch --tags origin
    )
    want="$(resolve_pin_commit "${pin}")"
  fi
  if [[ -z "${want}" ]]; then
    echo "error: pin ${pin} not resolvable after fetch" >&2
    exit 1
  fi
  local have
  have="$(git -C "${CORE}" rev-parse HEAD)"
  if [[ "${have}" != "${want}" ]]; then
    echo "error: core HEAD ${have} != SING_BOX_REV ${pin} (${want})" >&2
    echo "  run: scripts/prepare_core.sh --reset" >&2
    exit 1
  fi
  echo "prepare_core: exact pin OK ${pin} (${want})"
}

checkout_exact_pin() {
  local pin="${SING_BOX_REV:-}"
  if [[ -z "${pin}" ]]; then
    echo "error: SING_BOX_REV missing from ${VERSION_FILE}" >&2
    exit 1
  fi
  echo "prepare_core: resetting ${CORE} to pin ${pin}"
  (
    cd "${CORE}"
    git fetch --tags origin
    if git rev-parse --verify "${pin}^{commit}" >/dev/null 2>&1; then
      git checkout --force "${pin}"
    elif git rev-parse --verify "tags/${pin}" >/dev/null 2>&1; then
      git checkout --force "tags/${pin}"
    else
      echo "error: pin ${pin} not resolvable after fetch" >&2
      exit 1
    fi
    git clean -fd
    git submodule update --init --recursive
  )
}

verify_core_overlays() {
  local missing=0
  local rel
  for rel in \
    include/mieru.go \
    include/mieru_stub.go \
    option/mieru.go \
    protocol/mieru/outbound.go \
    protocol/mieru/inbound.go \
    option/v2ray_xhttp.go \
    option/wireguard_awg.go
  do
    if [[ ! -f "${CORE}/${rel}" ]]; then
      echo "MISSING ${CORE}/${rel}" >&2
      missing=1
    fi
  done
  if ! grep -q 'TypeMieru' "${CORE}/constant/proxy.go" 2>/dev/null; then
    echo "MISSING TypeMieru in constant/proxy.go" >&2
    missing=1
  fi
  if ! grep -q 'registerMieruOutbound' "${CORE}/include/registry.go" 2>/dev/null; then
    echo "MISSING registerMieruOutbound in include/registry.go" >&2
    missing=1
  fi
  if ! grep -q 'github.com/enfein/mieru/v3' "${CORE}/go.mod" 2>/dev/null; then
    echo "MISSING enfein/mieru/v3 in go.mod" >&2
    missing=1
  fi
  if ! grep -q 'V2RayTransportTypeXHTTP\|TypeXHTTP\|xhttp' "${CORE}/option/v2ray_transport.go" 2>/dev/null \
    && ! grep -q 'XHTTP' "${CORE}/option/v2ray_xhttp.go" 2>/dev/null; then
    echo "MISSING XHTTP registration/option evidence" >&2
    missing=1
  fi
  if ! grep -q 'AmneziaWGOptions\|header_protection_key' "${CORE}/option/wireguard_awg.go" 2>/dev/null; then
    echo "MISSING AWG options evidence" >&2
    missing=1
  fi
  # MASQUE: donor may use endpoint or outbound — require some evidence when with_masque not mandatory.
  if grep -Rql 'masque\|MASQUE\|TypeMasque' "${CORE}/option" "${CORE}/protocol" "${CORE}/constant" 2>/dev/null; then
    :
  else
    echo "WARNING: no MASQUE symbols found in core (capability may be absent)" >&2
  fi
  if [[ "${missing}" -ne 0 ]]; then
    echo "prepare_core verify FAILED" >&2
    exit 1
  fi
  echo "prepare_core verify OK (mieru/xhttp/awg overlays present)"
}

if [[ ! -d "${CORE}" ]]; then
  echo "error: ${CORE} missing — run: git submodule update --init --recursive" >&2
  echo "  or: ./scripts/bootstrap_core.sh" >&2
  exit 1
fi

load_version

case "${MODE}" in
  verify)
    ensure_exact_pin
    verify_core_overlays
    exit 0
    ;;
  reset)
    checkout_exact_pin
    ;;
  apply)
    ensure_exact_pin
    ;;
  apply-dirty)
    echo "prepare_core: WARNING apply-dirty skips exact pin checkout" >&2
    ;;
esac

echo "prepare_core: applying sing-box overlays"
bash "${ROOT}/scripts/apply_singbox_overlays.sh"
verify_core_overlays

# Fail closed: mieru must already be pinned in go.mod — never mutate via go get during release prepare.
if ! grep -q 'github.com/enfein/mieru/v3 v' "${CORE}/go.mod"; then
  echo "error: enfein/mieru/v3 version pin missing from go.mod after overlays" >&2
  exit 1
fi

echo "prepare_core OK"
