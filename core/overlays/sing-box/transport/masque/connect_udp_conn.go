package masque

import (
	"context"
	"net"
	"sync"
	"time"

	"github.com/sagernet/quic-go/http3"
	E "github.com/sagernet/sing/common/exceptions"
	M "github.com/sagernet/sing/common/metadata"
)

// requestStream is the subset of http3.RequestStream used by CONNECT-UDP.
type requestStream interface {
	ReceiveDatagram(context.Context) ([]byte, error)
	SendDatagram([]byte) error
	Close() error
}

// UDPConn is a net.PacketConn backed by one CONNECT-UDP HTTP/3 request stream.
type UDPConn struct {
	str         requestStream
	destination M.Socksaddr
	readDDL     time.Time
	writeDDL    time.Time
	closeOnce   sync.Once
	closed      chan struct{}
}

func NewUDPConn(str *http3.RequestStream, destination M.Socksaddr) *UDPConn {
	return &UDPConn{
		str:         str,
		destination: destination,
		closed:      make(chan struct{}),
	}
}

func (c *UDPConn) ReadFrom(p []byte) (n int, addr net.Addr, err error) {
	ctx := context.Background()
	if !c.readDDL.IsZero() {
		var cancel context.CancelFunc
		ctx, cancel = context.WithDeadline(ctx, c.readDDL)
		defer cancel()
	}
	select {
	case <-c.closed:
		return 0, nil, net.ErrClosed
	default:
	}
	data, err := c.str.ReceiveDatagram(ctx)
	if err != nil {
		return 0, nil, err
	}
	n = copy(p, data)
	if n < len(data) {
		return n, c.destination, E.New("connect-udp: short buffer")
	}
	return n, c.destination, nil
}

func (c *UDPConn) WriteTo(p []byte, addr net.Addr) (n int, err error) {
	select {
	case <-c.closed:
		return 0, net.ErrClosed
	default:
	}
	if err = c.str.SendDatagram(p); err != nil {
		return 0, err
	}
	return len(p), nil
}

func (c *UDPConn) Close() error {
	c.closeOnce.Do(func() {
		close(c.closed)
		_ = c.str.Close()
	})
	return nil
}

func (c *UDPConn) LocalAddr() net.Addr {
	return &net.UDPAddr{IP: net.IPv4zero, Port: 0}
}

func (c *UDPConn) SetDeadline(t time.Time) error {
	c.readDDL = t
	c.writeDDL = t
	return nil
}

func (c *UDPConn) SetReadDeadline(t time.Time) error {
	c.readDDL = t
	return nil
}

func (c *UDPConn) SetWriteDeadline(t time.Time) error {
	c.writeDDL = t
	return nil
}
