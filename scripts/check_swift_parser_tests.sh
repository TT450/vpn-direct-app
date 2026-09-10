#!/usr/bin/env bash
# Run VPNDirectParserPackage XCTests (detector → parser → builder → optional sing-box check).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="${ROOT}/tests/VPNDirectParserPackage"

# Prefer local Core binary when present (after prepare_core / check_parser_execution).
if [[ -x "${ROOT}/core/sing-box/sing-box" ]]; then
  export SING_BOX="${ROOT}/core/sing-box/sing-box"
fi

export VPN_DIRECT_CAPABILITY_JSON='{"magic":"VPN_DIRECT_CORE","api":1,"xhttp":true,"awg":true,"awgVersions":["2","3.0","3.1"],"masqueConnectIP":true,"vlessEncryption":true,"mieru":true,"hysteria2Obfuscations":["salamander","gecko"],"tags":"with_mieru,with_awg","protocols":{"vless":{"transports":["tcp","ws","grpc","httpupgrade","xhttp"],"security":["none","tls","reality"],"encryption":true},"mieru":{"supported":true},"hysteria2":{"supported":true,"obfuscation":["salamander","gecko"]},"amneziawg":{"supported":true,"versions":["2","3.0","3.1"]},"masque":{"connect_ip":true}}}'

cd "${PKG}"
swift test --package-path "${PKG}" 2>&1
echo "check_swift_parser_tests OK"
