package libbox

import (
	C "github.com/sagernet/sing-box/constant"
)

// Hysteria2 gecko obfuscation is present in the pinned sing-box-lx donor.
// Fail-closed consumers must read CapabilityJSON / this const — never infer from core name.
const vpnDirectTagGecko = true

// Compile-time proof: donor must keep the gecko obfuscation constant.
var _ = C.Hysteria2ObfsTypeGecko
