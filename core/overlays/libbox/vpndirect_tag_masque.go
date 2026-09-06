//go:build !vpn_direct_no_masque

package libbox

// MASQUE CONNECT-IP ships with sing-box-lx full client packages; Core 0.1 treats it as on
// unless an explicit trim tag is used.
const vpnDirectTagMASQUE = true

// VLESS encryption / PQ is part of the lx VLESS stack when building from sing-box-lx.
const vpnDirectTagVLESSEnc = true
