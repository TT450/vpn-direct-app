//go:build with_mieru

package libbox

// vpnDirectMieruEnsureRegistered reports that mieru is build-tagged in.
// Protocol registration happens via include/mieru.go (registerMieruInbound /
// registerMieruOutbound) when with_mieru is enabled — not from this overlay.
// CapabilityJSON uses vpnDirectTagMieru from vpndirect_tag_mieru.go.
func vpnDirectMieruEnsureRegistered() bool {
	return true
}
