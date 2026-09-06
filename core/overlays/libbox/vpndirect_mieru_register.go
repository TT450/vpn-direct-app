//go:build with_mieru

package libbox

// VPNDirectMieruRuntimeRegistered is set true only from a real mieru outbound
// registration path. Until protocol/mieru is merged and Register called, do not
// enable with_mieru in scripts/tags/*.tags.
//
// This file intentionally does not register an outbound by itself — enabling
// the tag without a protocol package must fail the build (missing symbols) or
// stay unused. CapabilityJSON reads VPNDirectSupportsMieru from tag stubs.
func vpnDirectMieruEnsureRegistered() bool {
	return false
}
