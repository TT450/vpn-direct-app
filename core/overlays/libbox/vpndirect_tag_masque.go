//go:build !vpn_direct_no_masque

package libbox

import (
	// Compile-time proofs: donor regression that removes these packages must break Libbox.
	_ "github.com/sagernet/sing-box/protocol/masque"
	"github.com/sagernet/sing-box/protocol/vless/encryption"
)

// MASQUE CONNECT-IP ships with sing-box-lx full client packages; Core treats it as on
// unless an explicit trim tag is used.
const vpnDirectTagMASQUE = true

// VLESS encryption / PQ is part of the lx VLESS stack when building from sing-box-lx.
const vpnDirectTagVLESSEnc = true

// Keep a typed reference so the encryption package cannot be trimmed without failing compile.
var _ = encryption.ClientInstance{}
