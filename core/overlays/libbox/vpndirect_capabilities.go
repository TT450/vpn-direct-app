package libbox

import (
	"runtime"
	"strings"
)

// VPN Direct Core capability surface exported to Swift via gomobile.
// Values are compile-time gated by sing-box build tags so the app can
// discover what the linked Libbox binary actually contains.

// VPNDirectCoreName is the product name stamped into Libbox builds.
func VPNDirectCoreName() string {
	return "VPNDirectCore"
}

// VPNDirectCoreVersion returns the VPN Direct Core semver (not the upstream sing-box tag).
func VPNDirectCoreVersion() string {
	if v := strings.TrimSpace(vpnDirectCoreVersionOverride); v != "" {
		return v
	}
	return "0.1.0"
}

// set via -ldflags "-X github.com/sagernet/sing-box/experimental/libbox.vpnDirectCoreVersionOverride=…"
var vpnDirectCoreVersionOverride string

// VPNDirectBuildTagsCSV returns the known feature tags compiled into this binary.
func VPNDirectBuildTagsCSV() string {
	return strings.Join(vpnDirectActiveTags(), ",")
}

// VPNDirectSupportsXHTTP reports whether transport type "xhttp" is available.
func VPNDirectSupportsXHTTP() bool { return vpnDirectTagXHTTP }

// VPNDirectSupportsAWG reports whether AmneziaWG fields are available on wireguard endpoints.
func VPNDirectSupportsAWG() bool { return vpnDirectTagAWG }

// VPNDirectSupportsMASQUEConnectIP reports CONNECT-IP MASQUE outbound support.
func VPNDirectSupportsMASQUEConnectIP() bool { return vpnDirectTagMASQUE }

// VPNDirectSupportsMASQUEConnectUDP is always false in Core 0.1 (not invented / not upstream).
func VPNDirectSupportsMASQUEConnectUDP() bool { return false }

// VPNDirectSupportsVLESSEncryption reports VLESS encryption / PQ string support.
func VPNDirectSupportsVLESSEncryption() bool { return vpnDirectTagVLESSEnc }

// VPNDirectSupportsMieru reports mieru outbound support (Phase K).
func VPNDirectSupportsMieru() bool { return vpnDirectTagMieru }

// VPNDirectCapabilityJSON is a compact JSON object for debugging / UI.
func VPNDirectCapabilityJSON() string {
	parts := []string{
		`"core":"` + VPNDirectCoreName() + `"`,
		`"version":"` + VPNDirectCoreVersion() + `"`,
		`"singBox":"` + Version() + `"`,
		`"go":"` + runtime.Version() + `"`,
		`"tags":"` + VPNDirectBuildTagsCSV() + `"`,
		`"xhttp":` + boolJSON(VPNDirectSupportsXHTTP()),
		`"awg":` + boolJSON(VPNDirectSupportsAWG()),
		`"masqueConnectIP":` + boolJSON(VPNDirectSupportsMASQUEConnectIP()),
		`"masqueConnectUDP":` + boolJSON(VPNDirectSupportsMASQUEConnectUDP()),
		`"vlessEncryption":` + boolJSON(VPNDirectSupportsVLESSEncryption()),
		`"mieru":` + boolJSON(VPNDirectSupportsMieru()),
	}
	return "{" + strings.Join(parts, ",") + "}"
}

func boolJSON(v bool) string {
	if v {
		return "true"
	}
	return "false"
}

func vpnDirectActiveTags() []string {
	var tags []string
	if vpnDirectTagXHTTP {
		tags = append(tags, "with_xhttp")
	}
	if vpnDirectTagAWG {
		tags = append(tags, "with_awg")
	}
	if vpnDirectTagIdleSuspend {
		tags = append(tags, "with_lx_idle_suspend")
	}
	if vpnDirectTagMieru {
		tags = append(tags, "with_mieru")
	}
	if vpnDirectTagMASQUE {
		tags = append(tags, "with_masque")
	}
	return tags
}
