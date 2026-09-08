//go:build with_shadowsocksr

package include

import (
	"github.com/sagernet/sing-box/adapter/outbound"
	"github.com/sagernet/sing-box/protocol/shadowsocksr"
)

func registerShadowsocksROutbound(registry *outbound.Registry) {
	shadowsocksr.RegisterOutbound(registry)
}
