//go:build with_shadowsocksr

package shadowsocksr

import (
	"context"
	"errors"
	"fmt"
	"net"

	"github.com/sagernet/sing-box/adapter"
	"github.com/sagernet/sing-box/adapter/outbound"
	"github.com/sagernet/sing-box/common/dialer"
	C "github.com/sagernet/sing-box/constant"
	"github.com/sagernet/sing-box/log"
	"github.com/sagernet/sing-box/option"
	"github.com/sagernet/sing-box/transport/clashssr/obfs"
	"github.com/sagernet/sing-box/transport/clashssr/protocol"
	"github.com/sagernet/sing-box/transport/clashssr/shadowsocks/core"
	"github.com/sagernet/sing-box/transport/clashssr/shadowsocks/shadowstream"
	"github.com/sagernet/sing-box/transport/clashssr/socks5"
	"github.com/sagernet/sing/common/bufio"
	E "github.com/sagernet/sing/common/exceptions"
	"github.com/sagernet/sing/common/logger"
	M "github.com/sagernet/sing/common/metadata"
	N "github.com/sagernet/sing/common/network"
)

func RegisterOutbound(registry *outbound.Registry) {
	outbound.Register[option.ShadowsocksROutboundOptions](registry, C.TypeShadowsocksR, NewOutbound)
}

var _ adapter.Outbound = (*Outbound)(nil)

type Outbound struct {
	outbound.Adapter
	logger     logger.ContextLogger
	dialer     N.Dialer
	serverAddr M.Socksaddr
	cipher     core.Cipher
	obfs       obfs.Obfs
	protocol   protocol.Protocol
}

func NewOutbound(ctx context.Context, router adapter.Router, logger log.ContextLogger, tag string, options option.ShadowsocksROutboundOptions) (adapter.Outbound, error) {
	outboundDialer, err := dialer.New(ctx, options.DialerOptions, options.ServerIsDomain())
	if err != nil {
		return nil, err
	}
	outbound := &Outbound{
		Adapter:    outbound.NewAdapterWithDialerOptions(C.TypeShadowsocksR, tag, options.Network.Build(), options.DialerOptions),
		logger:     logger,
		dialer:     outboundDialer,
		serverAddr: options.ServerOptions.Build(),
	}
	var cipherName string
	switch options.Method {
	case "none":
		cipherName = "dummy"
	default:
		cipherName = options.Method
	}
	outbound.cipher, err = core.PickCipher(cipherName, nil, options.Password)
	if err != nil {
		return nil, err
	}
	var (
		ivSize int
		key    []byte
	)
	if cipherName == "dummy" {
		ivSize = 0
		key = core.Kdf(options.Password, 16)
	} else {
		streamCipher, ok := outbound.cipher.(*core.StreamCipher)
		if !ok {
			return nil, fmt.Errorf("%s is not none or a supported stream cipher in ssr", cipherName)
		}
		ivSize = streamCipher.IVSize()
		key = streamCipher.Key
	}
	obfsInstance, obfsOverhead, err := obfs.PickObfs(options.Obfs, &obfs.Base{
		Host:   options.Server,
		Port:   int(options.ServerPort),
		Key:    key,
		IVSize: ivSize,
		Param:  options.ObfsParam,
	})
	if err != nil {
		return nil, E.Cause(err, "initialize obfs")
	}
	protocolInstance, err := protocol.PickProtocol(options.Protocol, &protocol.Base{
		Key:      key,
		Overhead: obfsOverhead,
		Param:    options.ProtocolParam,
	})
	if err != nil {
		return nil, E.Cause(err, "initialize protocol")
	}
	outbound.obfs = obfsInstance
	outbound.protocol = protocolInstance
	return outbound, nil
}

func (h *Outbound) DialContext(ctx context.Context, network string, destination M.Socksaddr) (net.Conn, error) {
	ctx, metadata := adapter.ExtendContext(ctx)
	metadata.Outbound = h.Tag()
	metadata.Destination = destination
	switch N.NetworkName(network) {
	case N.NetworkTCP:
		h.logger.InfoContext(ctx, "outbound connection to ", destination)
		conn, err := h.dialer.DialContext(ctx, network, h.serverAddr)
		if err != nil {
			return nil, err
		}
		conn = h.cipher.StreamConn(h.obfs.StreamConn(conn))
		var writeIV []byte
		if streamConn, ok := conn.(*shadowstream.Conn); ok {
			writeIV, err = streamConn.ObtainWriteIV()
			if err != nil {
				conn.Close()
				return nil, err
			}
		}
		conn = h.protocol.StreamConn(conn, writeIV)
		err = M.SocksaddrSerializer.WriteAddrPort(conn, destination)
		if err != nil {
			conn.Close()
			return nil, E.Cause(err, "write request")
		}
		return conn, nil
	case N.NetworkUDP:
		conn, err := h.ListenPacket(ctx, destination)
		if err != nil {
			return nil, err
		}
		return bufio.NewBindPacketConn(conn, destination), nil
	default:
		return nil, E.Extend(N.ErrUnknownNetwork, network)
	}
}

func (h *Outbound) ListenPacket(ctx context.Context, destination M.Socksaddr) (net.PacketConn, error) {
	ctx, metadata := adapter.ExtendContext(ctx)
	metadata.Outbound = h.Tag()
	metadata.Destination = destination
	h.logger.InfoContext(ctx, "outbound packet connection to ", destination)
	outConn, err := h.dialer.DialContext(ctx, N.NetworkUDP, h.serverAddr)
	if err != nil {
		return nil, err
	}
	packetConn := h.cipher.PacketConn(bufio.NewUnbindPacketConn(outConn))
	packetConn = h.protocol.PacketConn(packetConn)
	return &ssPacketConn{PacketConn: packetConn, rAddr: outConn.RemoteAddr()}, nil
}

type ssPacketConn struct {
	net.PacketConn
	rAddr net.Addr
}

func (spc *ssPacketConn) WriteTo(b []byte, addr net.Addr) (n int, err error) {
	packet, err := socks5.EncodeUDPPacket(socks5.ParseAddrToSocksAddr(addr), b)
	if err != nil {
		return
	}
	return spc.PacketConn.WriteTo(packet[3:], spc.rAddr)
}

func (spc *ssPacketConn) ReadFrom(b []byte) (int, net.Addr, error) {
	n, _, e := spc.PacketConn.ReadFrom(b)
	if e != nil {
		return 0, nil, e
	}

	addr := socks5.SplitAddr(b[:n])
	if addr == nil {
		return 0, nil, errors.New("parse addr error")
	}

	udpAddr := addr.UDPAddr()
	if udpAddr == nil {
		return 0, nil, errors.New("parse addr error")
	}

	copy(b, b[len(addr):])
	return n - len(addr), udpAddr, e
}
