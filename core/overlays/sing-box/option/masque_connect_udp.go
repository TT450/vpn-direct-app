package option

import "github.com/sagernet/sing/common/json/badoption"

// MASQUEConnectUDPOutboundOptions configures a MASQUE CONNECT-UDP (RFC 9298) outbound.
// This is a UDP proxy over HTTP/3 Extended CONNECT — not CONNECT-IP (RFC 9484 / type "masque").
type MASQUEConnectUDPOutboundOptions struct {
	DialerOptions
	ServerOptions
	OutboundTLSOptionsContainer

	// URI is the CONNECT-UDP request URI template. Placeholders:
	//   {target_host} {target_port}
	// Default: https://{server}/.well-known/masque/udp/{target_host}/{target_port}/
	URI string `json:"uri,omitempty"`

	// VHTTP selects the HTTP version. Only "h3" is supported for CONNECT-UDP datagrams.
	VHTTP string `json:"vhttp,omitempty" enum:"h3"`

	// KeepAlivePeriod is the QUIC keepalive interval. Empty = 30s.
	KeepAlivePeriod badoption.Duration `json:"keep_alive_period,omitempty"`

	// NetworkList is the L4 allow-list. Empty = udp only (CONNECT-UDP has no TCP).
	NetworkList NetworkList `json:"network_list,omitempty"`
}
