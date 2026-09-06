# Building VPN Direct Core / Libbox

## Prerequisites

- macOS with Xcode
- Go toolchain matching `core/sing-box/go.version` (or `core/VERSION` pin)
- `gomobile` (installed by build script if missing)
- Git with submodule support

```bash
# Apple Command Line Tools / Xcode
xcode-select -p

# Go (example — use pinned version from core/VERSION)
go version
```

## Bootstrap submodule

```bash
cd "/path/to/Direct VPN Client"
./scripts/bootstrap_core.sh
# equivalent:
# git submodule update --init --recursive
```

Remotes: see [`REMOTES.md`](REMOTES.md). Pins land in `core/VERSION`.

Tracked overlays under `core/overlays/libbox/` (capability exports) are copied into the submodule during `scripts/build_libbox.sh`.

## Backup stock Libbox

```bash
make libbox-backup-stock
# → Libbox.xcframework.stock/
```

## Build Libbox (vpn_direct_ios)

```bash
make libbox
# or:
./scripts/build_libbox.sh
```

Default Apple platforms: `ios,iossimulator,macos,tvos`. Faster iOS-only:

```bash
VPN_DIRECT_APPLE_PLATFORM=ios,iossimulator ./scripts/build_libbox.sh
```

Output: `Libbox.xcframework` at the project root (replaces previous). Sidecar stamp: `Libbox.xcframework/VPNDirectCore.version`.

Go: donor `go.version` / `go.mod` may require a newer toolchain than system Go; the build uses the module’s toolchain when available.

## Rollback

```bash
make libbox-restore-stock
```

## Build Apple app

```bash
xcodebuild -scheme SFI -configuration Debug -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData -allowProvisioningUpdates build
```

## Validate fixtures

```bash
make check-fixtures
# or: ./scripts/check_fixtures.sh
```

## Validate core configs (optional)

```bash
cd core/sing-box
make -f Makefile.lx lx-build   # desktop binary with lx tags
./sing-box check -c lx-test/config/xhttp_reality.json
./sing-box check -c lx-test/config/awg2_basic.json
```

## Version pins

See `core/VERSION`.
