package masque

import (
	"context"
	"net/http"
	"net/url"
	"strconv"
	"strings"

	"github.com/sagernet/quic-go/http3"
	E "github.com/sagernet/sing/common/exceptions"
	M "github.com/sagernet/sing/common/metadata"
)

const connectUDPProtocol = "connect-udp"

// ConnectUDPStream dials one RFC 9298 CONNECT-UDP session for destination over an existing H3 client.
func ConnectUDPStream(ctx context.Context, conn *http3.ClientConn, connectURI string, destination M.Socksaddr) (*UDPConn, error) {
	u, err := url.Parse(connectURI)
	if err != nil {
		return nil, E.Cause(err, "parse connect-udp uri")
	}

	select {
	case <-ctx.Done():
		return nil, context.Cause(ctx)
	case <-conn.Context().Done():
		return nil, context.Cause(conn.Context())
	case <-conn.ReceivedSettings():
	}
	settings := conn.Settings()
	if !settings.EnableExtendedConnect {
		return nil, E.New("connect-udp: server didn't enable Extended CONNECT")
	}
	if !settings.EnableDatagrams {
		return nil, E.New("connect-udp: server didn't enable datagrams")
	}

	rstr, err := conn.OpenRequestStream(ctx)
	if err != nil {
		return nil, E.Cause(err, "open request stream")
	}

	req := &http.Request{
		Method: http.MethodConnect,
		Proto:  connectUDPProtocol,
		Host:   u.Host,
		Header: http.Header{
			http3.CapsuleProtocolHeader: []string{capsuleProtocolHeaderValue},
			"User-Agent":                []string{""},
		},
		URL: u,
	}
	if err = rstr.SendRequestHeader(req); err != nil {
		_ = rstr.Close()
		return nil, E.Cause(err, "send connect-udp request")
	}
	rsp, err := rstr.ReadResponse()
	if err != nil {
		_ = rstr.Close()
		return nil, E.Cause(err, "read connect-udp response")
	}
	if rsp.StatusCode < 200 || rsp.StatusCode > 299 {
		_ = rstr.Close()
		return nil, E.New("connect-udp: server responded with ", rsp.StatusCode)
	}
	return NewUDPConn(rstr, destination), nil
}

// ExpandConnectUDPURI fills {target_host}/{target_port} (and legacy {host}/{port}) in a template.
func ExpandConnectUDPURI(template string, server string, destination M.Socksaddr) string {
	host := destination.AddrString()
	port := strconv.FormatUint(uint64(destination.Port), 10)
	out := template
	if out == "" {
		authority := server
		if !strings.Contains(authority, "://") {
			authority = "https://" + authority
		}
		out = strings.TrimRight(authority, "/") + "/.well-known/masque/udp/{target_host}/{target_port}/"
	}
	replacer := strings.NewReplacer(
		"{target_host}", host,
		"{target_port}", port,
		"{host}", host,
		"{port}", port,
	)
	return replacer.Replace(out)
}
