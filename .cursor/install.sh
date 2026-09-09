#!/usr/bin/env bash
#
# Cloud Agent install for VPN Direct.
#
# Prepares the Linux-runnable development surface for this repository:
#   * the Go "VPN Direct Core" (sing-box) toolchain + submodules + overlays
#   * the Python/jq fixture, subscription-graph, parser and matrix checks
#
# The native Apple app targets (SFI/SFM/SFT) and the Swift parser package
# (tests/VPNDirectParserPackage, declared platforms: [.macOS]) require macOS +
# Xcode and are intentionally out of scope for this Linux environment.
#
# Idempotent and safe to re-run: every step checks current state first.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GO_VERSION="go1.26.6"          # pinned by core/VERSION (GO_VERSION) / core/sing-box go.version
LLVM_VERSION="20"              # lld-20: correct CREL relocation support for the cronet static lib

log() { printf '\n=== %s ===\n' "$*"; }

# ---------------------------------------------------------------------------
# 1. System packages
# ---------------------------------------------------------------------------
log "apt: base packages"
export DEBIAN_FRONTEND=noninteractive
# Best-effort refresh: a broken/unrelated third-party repo (e.g. a preconfigured
# Google Chrome source) must not abort setup. The base packages below are part of
# the standard image; install reconciles from whatever indexes are available.
sudo apt-get update -qq || echo "warning: apt-get update reported errors (continuing with cached indexes)"
sudo apt-get install -y -qq \
  build-essential ca-certificates curl git gnupg jq python3 pkg-config

# ---------------------------------------------------------------------------
# 2. lld-20 (from apt.llvm.org)
#    The prebuilt cronet-go static archive (pulled in by with_naive_outbound)
#    uses CREL compressed-relocation sections. GNU ld 2.42, mold and lld<=18
#    cannot link it correctly; lld-20 can. We route Go's external linker
#    through it via a CC wrapper (see step 5) so plain `go build`/`go test`
#    from the check scripts work unmodified.
# ---------------------------------------------------------------------------
if ! command -v "ld.lld-${LLVM_VERSION}" >/dev/null 2>&1; then
  log "install lld-${LLVM_VERSION}"
  . /etc/os-release
  curl -fsSL https://apt.llvm.org/llvm-snapshot.gpg.key \
    | sudo tee /etc/apt/trusted.gpg.d/apt.llvm.org.asc >/dev/null
  echo "deb http://apt.llvm.org/${VERSION_CODENAME}/ llvm-toolchain-${VERSION_CODENAME}-${LLVM_VERSION} main" \
    | sudo tee "/etc/apt/sources.list.d/llvm-${LLVM_VERSION}.list" >/dev/null
  # Update only the LLVM source so an unrelated broken repo cannot block it.
  sudo apt-get update -qq \
    -o Dir::Etc::sourcelist="sources.list.d/llvm-${LLVM_VERSION}.list" \
    -o Dir::Etc::sourceparts="-" \
    -o APT::Get::List-Cleanup="0"
  sudo apt-get install -y -qq "lld-${LLVM_VERSION}"
else
  log "lld-${LLVM_VERSION} already present"
fi

# ---------------------------------------------------------------------------
# 3. Go toolchain (pinned)
# ---------------------------------------------------------------------------
if ! /usr/local/go/bin/go version 2>/dev/null | grep -q "${GO_VERSION} "; then
  log "install Go ${GO_VERSION}"
  tmp="$(mktemp -d)"
  curl -fsSL -o "${tmp}/go.tgz" "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "${tmp}/go.tgz"
  rm -rf "${tmp}"
else
  log "Go ${GO_VERSION} already installed"
fi
sudo ln -sf /usr/local/go/bin/go /usr/local/bin/go
sudo ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
# Convenience for interactive/login shells (GOBIN etc.); toolchains are also
# reachable via the /usr/local/bin symlinks above regardless of PATH.
echo 'export PATH="/usr/local/go/bin:$PATH"' | sudo tee /etc/profile.d/vpn-direct-go.sh >/dev/null

# ---------------------------------------------------------------------------
# 4. CC wrapper -> lld-20
# ---------------------------------------------------------------------------
log "install cc-lld wrapper"
sudo tee /usr/local/bin/cc-lld >/dev/null <<EOF
#!/bin/sh
# gcc that links with lld-${LLVM_VERSION} (deterministic via -B); used as Go's CC/external linker.
exec /usr/bin/gcc -B/usr/lib/llvm-${LLVM_VERSION}/bin -fuse-ld=lld "\$@"
EOF
sudo chmod +x /usr/local/bin/cc-lld

# ---------------------------------------------------------------------------
# 5. Persist Go build configuration (read by every go command, PATH-independent)
#    * CC   : link cronet via lld-20
#    * GOFLAGS -checklinkname=0 : allow sing-box's //go:linkname pulls
#      (experimental/libbox -> runtime/pprof.parseProcSelfMaps) under Go 1.26
#    * GOTOOLCHAIN=local : never auto-download a different toolchain
# ---------------------------------------------------------------------------
log "configure go env"
/usr/local/go/bin/go env -w CC=/usr/local/bin/cc-lld
/usr/local/go/bin/go env -w GOFLAGS=-ldflags=-checklinkname=0
/usr/local/go/bin/go env -w GOTOOLCHAIN=local

# ---------------------------------------------------------------------------
# 6. Submodules + Core overlays
# ---------------------------------------------------------------------------
log "git submodules"
git -C "${ROOT}" submodule update --init --recursive

log "prepare Core (apply sing-box overlays)"
"${ROOT}/scripts/prepare_core.sh"

log "install complete"
