// Package masqueconnectudp implements the MASQUE CONNECT-UDP (RFC 9298) outbound.
package masqueconnectudp

import (
	"context"
	"net"
	"sync"
	"time"

	"github.com/sagernet/quic-go"
	"github.com/sagernet/quic-go/http3"
	"github.com/sagernet/sing-box/adapter"
	"github.com/sagernet/sing-box/adapter/outbound"
	"github.com/sagernet/sing-box/common/dialer"
	"github.com/sagernet/sing-box/common/tls"
	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing-box/transport/masque"
	"github.com/sagernet/sing/common"
	"github.com/sagernet/sing/common/bufio"
	E "github.com/sagernet/sing/common/exceptions"
	"github.com/sagernet/sing/common/logger"
	M "github.com/sagernet/sing/common/metadata"
	N "github.com/sagernet/sing/common/network"
)

func RegisterOutbound(registry *outbound.Registry) {
	outbound.Register[option.MASQUEConnectUDPOutboundOptions](registry, C.TypeMASQUEConnectUDP, NewOutbound)
}

var _ adapter.Outbound = (*Outbound)(nil)

type Outbound struct {
	outbound.Adapter
	logger          logger.ContextLogger
	dialer          N.Dialer
	server          M.Socksaddr
	uriTemplate     string
	tlsConfig       *tls.STDConfig
	keepAlivePeriod time.Duration
	quicConfig      *quic.Config

	access   sync.Mutex
	quicConn *quic.Conn
	h3       *http3.Transport
	h3Client *http3.ClientConn
}

func NewOutbound(ctx context.Context, router adapter.Router, logger log.ContextLogger, tag string, options option.MASQUEConnectUDPOutboundOptions) (adapter.Outbound, error) {
	vhttp := options.VHTTP
	if vhttp == "" {
		vhttp = "h3"
	}
	if vhttp != "h3" {
		return nil, E.New("masque-connect-udp: only vhttp=h3 is supported")
	}
	networks := options.NetworkList.Build()
	if len(networks) == 0 {
		networks = []string{N.NetworkUDP}
	}
	for _, n := range networks {
		if n == N.NetworkTCP {
			return nil, E.New("masque-connect-udp: TCP is not supported (RFC 9298 is UDP-only)")
		}
	}

	options.UDPFragmentDefault = true
	outboundDialer, err := dialer.New(ctx, options.DialerOptions, options.ServerIsDomain())
	if err != nil {
		return nil, err
	}
	server := options.ServerOptions.Build()
	if !server.IsValid() {
		return nil, E.New("masque-connect-udp: missing server")
	}

	tlsOptions := common.PtrValueOrDefault(options.TLS)
	tlsOptions.Enabled = true
	if tlsOptions.ServerName == "" {
		tlsOptions.ServerName = options.Server
	}
	if len(tlsOptions.ALPN) == 0 {
		tlsOptions.ALPN = []string{http3.NextProtoH3}
	}
	tlsClient, err := tls.NewClient(ctx, logger, options.Server, tlsOptions)
	if err != nil {
		return nil, err
	}
	stdConfig, err := tlsClient.STDConfig()
	if err != nil {
		return nil, err
	}

	keepAlive := 30 * time.Second
	if options.KeepAlivePeriod > 0 {
		keepAlive = time.Duration(options.KeepAlivePeriod)
	} else if options.KeepAlivePeriod < 0 {
		keepAlive = 0
	}

	return &Outbound{
		Adapter:     outbound.NewAdapterWithDialerOptions(C.TypeMASQUEConnectUDP, tag, networks, options.DialerOptions),
		logger:      logger,
		dialer:      outboundDialer,
		server:      server,
		uriTemplate: options.URI,
		tlsConfig:   stdConfig,
		quicConfig: &quic.Config{
			EnableDatagrams:   true,
			InitialPacketSize: 1242,
			KeepAlivePeriod:   keepAlive,
		},
	}, nil
}

func (o *Outbound) DialContext(ctx context.Context, network string, destination M.Socksaddr) (net.Conn, error) {
	if N.NetworkName(network) != N.NetworkUDP {
		return nil, E.New("masque-connect-udp: only UDP is supported")
	}
	packetConn, err := o.ListenPacket(ctx, destination)
	if err != nil {
		return nil, err
	}
	return bufio.NewBindPacketConn(packetConn, destination), nil
}

func (o *Outbound) ListenPacket(ctx context.Context, destination M.Socksaddr) (net.PacketConn, error) {
	ctx, metadata := adapter.ExtendContext(ctx)
	metadata.Outbound = o.Tag()
	metadata.Destination = destination
	o.logger.InfoContext(ctx, "outbound CONNECT-UDP packet connection to ", destination)

	client, err := o.ensureH3(ctx)
	if err != nil {
		return nil, err
	}
	uri := masque.ExpandConnectUDPURI(o.uriTemplate, o.server.AddrString(), destination)
	return masque.ConnectUDPStream(ctx, client, uri, destination)
}

func (o *Outbound) Close() error {
	o.access.Lock()
	defer o.access.Unlock()
	if o.h3 != nil {
		_ = o.h3.Close()
		o.h3 = nil
	}
	o.h3Client = nil
	if o.quicConn != nil {
		_ = o.quicConn.CloseWithError(0, "")
		o.quicConn = nil
	}
	return nil
}

func (o *Outbound) ensureH3(ctx context.Context) (*http3.ClientConn, error) {
	o.access.Lock()
	defer o.access.Unlock()
	if o.h3Client != nil && o.quicConn != nil {
		select {
		case <-o.quicConn.Context().Done():
			o.h3Client = nil
			if o.h3 != nil {
				_ = o.h3.Close()
				o.h3 = nil
			}
			o.quicConn = nil
		default:
			return o.h3Client, nil
		}
	}

	udpConn, err := o.dialer.DialContext(ctx, N.NetworkUDP, o.server)
	if err != nil {
		return nil, E.Cause(err, "dial masque-connect-udp server")
	}
	quicConn, err := quic.DialEarly(ctx, bufio.NewUnbindPacketConn(udpConn), udpConn.RemoteAddr(), o.tlsConfig, o.quicConfig)
	if err != nil {
		_ = udpConn.Close()
		return nil, E.Cause(err, "quic dial masque-connect-udp")
	}
	tr := &http3.Transport{
		EnableDatagrams:    true,
		DisableCompression: true,
	}
	client := tr.NewClientConn(quicConn)
	o.quicConn = quicConn
	o.h3 = tr
	o.h3Client = client
	return client, nil
}
