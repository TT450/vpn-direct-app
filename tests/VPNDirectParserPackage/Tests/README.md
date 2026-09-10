# VPNDirectParserTests

Swift Package (`tests/VPNDirectParserPackage`) compiling real `Library/Service/VPNDirect/*` sources via symlinks under `Sources/VPNDirectParsers` (SPM cannot reference paths outside the package root).

Includes a `Libbox` stub and lightweight `SubscriptionMetadata` / `SubscriptionConfigBuilder` stubs so parsers build without the app XCFramework.

```bash
./scripts/check_swift_parser_tests.sh
# or
make check-swift-parser-tests
```

Sets `VPN_DIRECT_CAPABILITY_JSON` so builders see XHTTP/Mieru/AWG. When `core/sing-box/sing-box` exists, tests also run `sing-box check`.
