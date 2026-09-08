package socks5

import (
	"errors"
	"net"
)

// Error represents a SOCKS error
type Error byte

func (err Error) Error() string {
	return "SOCKS error"
}

// SOCKS address types as defined in RFC 1928 section 5.
const (
	AtypIPv4       = 1
	AtypDomainName = 3
	AtypIPv6       = 4
)

// MaxAddrLen is the maximum size of SOCKS address in bytes.
const MaxAddrLen = 1 + 1 + 255 + 2

// Addr represents a SOCKS address as specified in RFC 1928 section 5.
type Addr []byte

func (a Addr) String() string {
	if len(a) == 0 {
		return ""
	}
	var host string
	switch a[0] {
	case AtypDomainName:
		host = string(a[2 : 2+int(a[1])])
	case AtypIPv4:
		host = net.IP(a[1 : 1+net.IPv4len]).String()
	case AtypIPv6:
		host = net.IP(a[1 : 1+net.IPv6len]).String()
	default:
		return ""
	}
	port := (int(a[len(a)-2]) << 8) | int(a[len(a)-1])
	return net.JoinHostPort(host, itoa(port))
}

func (a Addr) UDPAddr() *net.UDPAddr {
	if len(a) == 0 {
		return nil
	}
	var ip net.IP
	switch a[0] {
	case AtypIPv4:
		ip = make(net.IP, net.IPv4len)
		copy(ip, a[1:1+net.IPv4len])
	case AtypIPv6:
		ip = make(net.IP, net.IPv6len)
		copy(ip, a[1:1+net.IPv6len])
	default:
		return nil
	}
	return &net.UDPAddr{IP: ip, Port: (int(a[len(a)-2]) << 8) | int(a[len(a)-1])}
}

// SplitAddr slices a SOCKS address from beginning of b. Returns nil if failed.
func SplitAddr(b []byte) Addr {
	if len(b) < 2 {
		return nil
	}
	var addrLen int
	switch b[0] {
	case AtypDomainName:
		if len(b) < 2 {
			return nil
		}
		addrLen = 1 + 1 + int(b[1]) + 2
	case AtypIPv4:
		addrLen = 1 + net.IPv4len + 2
	case AtypIPv6:
		addrLen = 1 + net.IPv6len + 2
	default:
		return nil
	}
	if len(b) < addrLen {
		return nil
	}
	return b[:addrLen]
}

// ParseAddrToSocksAddr parse a socks addr from net.Addr
func ParseAddrToSocksAddr(addr net.Addr) Addr {
	var ip net.IP
	var port int
	switch v := addr.(type) {
	case *net.UDPAddr:
		ip = v.IP
		port = v.Port
	case *net.TCPAddr:
		ip = v.IP
		port = v.Port
	default:
		return ParseAddr(addr.String())
	}
	return encodeIP(ip, port)
}

// ParseAddr parses the address in string s to Addr.
func ParseAddr(s string) Addr {
	host, portStr, err := net.SplitHostPort(s)
	if err != nil {
		return nil
	}
	port, err := net.LookupPort("tcp", portStr)
	if err != nil {
		return nil
	}
	if ip := net.ParseIP(host); ip != nil {
		return encodeIP(ip, port)
	}
	if len(host) > 255 {
		return nil
	}
	buf := make([]byte, 1+1+len(host)+2)
	buf[0] = AtypDomainName
	buf[1] = byte(len(host))
	copy(buf[2:], host)
	buf[len(buf)-2], buf[len(buf)-1] = byte(port>>8), byte(port)
	return buf
}

func encodeIP(ip net.IP, port int) Addr {
	if ip4 := ip.To4(); ip4 != nil {
		buf := make([]byte, 1+net.IPv4len+2)
		buf[0] = AtypIPv4
		copy(buf[1:], ip4)
		buf[len(buf)-2], buf[len(buf)-1] = byte(port>>8), byte(port)
		return buf
	}
	ip6 := ip.To16()
	if ip6 == nil {
		return nil
	}
	buf := make([]byte, 1+net.IPv6len+2)
	buf[0] = AtypIPv6
	copy(buf[1:], ip6)
	buf[len(buf)-2], buf[len(buf)-1] = byte(port>>8), byte(port)
	return buf
}

func EncodeUDPPacket(addr Addr, payload []byte) (packet []byte, err error) {
	if addr == nil {
		return nil, errors.New("invalid addr")
	}
	packet = make([]byte, 3+len(addr)+len(payload))
	packet[0], packet[1], packet[2] = 0, 0, 0
	copy(packet[3:], addr)
	copy(packet[3+len(addr):], payload)
	return packet, nil
}


func itoa(i int) string {
	if i == 0 {
		return "0"
	}
	var b [12]byte
	pos := len(b)
	for i > 0 {
		pos--
		b[pos] = byte('0' + i%10)
		i /= 10
	}
	return string(b[pos:])
}
