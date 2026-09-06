package libbox

import (
	"encoding/json"
	"runtime"
	"strings"
)

// VPN Direct Core capability surface exported to Swift via gomobile.
// Values are compile-time gated by sing-box build tags so the app can
// discover what the linked Libbox binary actually contains.
//
// Capability discovery is fail-closed: unproven features must report false.

const (
	vpnDirectCoreMagicValue      = "VPN_DIRECT_CORE"
	vpnDirectCoreAPIVersionValue = 1
)

// VPNDirectCoreMagic is a stable ABI marker for VPN Direct Libbox builds.
func VPNDirectCoreMagic() string {
	return vpnDirectCoreMagicValue
}

// VPNDirectCoreAPIVersion is the capability JSON / export schema version.
func VPNDirectCoreAPIVersion() int {
	return vpnDirectCoreAPIVersionValue
}

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

// VPNDirectAWGVersionsCSV lists AmneziaWG generations proven in this pin (empty if !AWG).
func VPNDirectAWGVersionsCSV() string {
	if !vpnDirectTagAWG {
		return ""
	}
	return strings.Join(vpnDirectAWGVersions(), ",")
}

// VPNDirectHysteria2ObfuscationsCSV lists proven Hysteria2 obfuscation types.
func VPNDirectHysteria2ObfuscationsCSV() string {
	return strings.Join(vpnDirectHysteria2Obfuscations(), ",")
}

type vpnDirectCapabilityDocument struct {
	API     int    `json:"api"`
	Magic   string `json:"magic"`
	Core    string `json:"core"`
	Version string `json:"version"`
	SingBox string `json:"singBox"`
	Go      string `json:"go"`
	Tags    string `json:"tags"`
	XHTTP   bool   `json:"xhttp"`
	AWG     bool   `json:"awg"`
	AWGVersions []string `json:"awgVersions"`
	MasqueConnectIP  bool `json:"masqueConnectIP"`
	MasqueConnectUDP bool `json:"masqueConnectUDP"`
	VLESSEncryption  bool `json:"vlessEncryption"`
	Mieru            bool `json:"mieru"`
	Hysteria2Obfuscations []string `json:"hysteria2Obfuscations"`
	Transports struct {
		XHTTP bool `json:"xhttp"`
	} `json:"transports"`
	Protocols struct {
		AmneziaWG struct {
			Supported bool     `json:"supported"`
			Versions  []string `json:"versions"`
		} `json:"amneziawg"`
		Hysteria2 struct {
			Obfuscation []string `json:"obfuscation"`
		} `json:"hysteria2"`
		Masque struct {
			ConnectIP  bool `json:"connect_ip"`
			ConnectUDP bool `json:"connect_udp"`
		} `json:"masque"`
		Mieru struct {
			Supported bool `json:"supported"`
		} `json:"mieru"`
		VLESS struct {
			Encryption bool `json:"encryption"`
		} `json:"vless"`
	} `json:"protocols"`
}

// VPNDirectCapabilityJSON is the preferred versioned capability document for Swift.
func VPNDirectCapabilityJSON() string {
	doc := vpnDirectCapabilityDocument{
		API:     vpnDirectCoreAPIVersionValue,
		Magic:   vpnDirectCoreMagicValue,
		Core:    VPNDirectCoreName(),
		Version: VPNDirectCoreVersion(),
		SingBox: Version(),
		Go:      runtime.Version(),
		Tags:    VPNDirectBuildTagsCSV(),
		XHTTP:   VPNDirectSupportsXHTTP(),
		AWG:     VPNDirectSupportsAWG(),
		AWGVersions:          vpnDirectAWGVersions(),
		MasqueConnectIP:      VPNDirectSupportsMASQUEConnectIP(),
		MasqueConnectUDP:     VPNDirectSupportsMASQUEConnectUDP(),
		VLESSEncryption:      VPNDirectSupportsVLESSEncryption(),
		Mieru:                VPNDirectSupportsMieru(),
		Hysteria2Obfuscations: vpnDirectHysteria2Obfuscations(),
	}
	doc.Transports.XHTTP = VPNDirectSupportsXHTTP()
	doc.Protocols.AmneziaWG.Supported = VPNDirectSupportsAWG()
	doc.Protocols.AmneziaWG.Versions = vpnDirectAWGVersions()
	doc.Protocols.Hysteria2.Obfuscation = vpnDirectHysteria2Obfuscations()
	doc.Protocols.Masque.ConnectIP = VPNDirectSupportsMASQUEConnectIP()
	doc.Protocols.Masque.ConnectUDP = VPNDirectSupportsMASQUEConnectUDP()
	doc.Protocols.Mieru.Supported = VPNDirectSupportsMieru()
	doc.Protocols.VLESS.Encryption = VPNDirectSupportsVLESSEncryption()

	data, err := json.Marshal(doc)
	if err != nil {
		return `{"api":1,"magic":"VPN_DIRECT_CORE","error":"marshal"}`
	}
	return string(data)
}

func vpnDirectAWGVersions() []string {
	if !vpnDirectTagAWG {
		return nil
	}
	// Donor sing-box-lx pin exposes AWG generations 1 / 2 / 3.0 / 3.1.
	return []string{"1", "2", "3.0", "3.1"}
}

func vpnDirectHysteria2Obfuscations() []string {
	// Salamander is upstream Hysteria2; gecko is present in this lx pin (see donor changelog).
	out := []string{"salamander"}
	if vpnDirectTagGecko {
		out = append(out, "gecko")
	}
	return out
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
