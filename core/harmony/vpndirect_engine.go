//go:build openharmony && arm64

package main

/*
#cgo CFLAGS: -fPIC
#include <stdint.h>
*/
import "C"

import (
	"encoding/json"
	"errors"
	"net"
	"net/netip"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/sagernet/sing-box/experimental/libbox"
)

const (
	stateConnecting    = "Connecting"
	stateConnected     = "Connected"
	stateDisconnecting = "Disconnecting"
	stateDisconnected  = "Disconnected"
	stateFailed        = "Failed"
)

type harmonyProfile struct {
	StatePath     string `json:"statePath"`
	SingBoxConfig string `json:"singBoxConfig"`
}

var (
	mu        sync.Mutex
	service   *libbox.BoxService
	tunFD     = -1
	statePath string
)

type stringIterator struct {
	items []string
	index int
}

func (it *stringIterator) HasNext() bool { return it.index < len(it.items) }
func (it *stringIterator) Next() string {
	if !it.HasNext() {
		return ""
	}
	value := it.items[it.index]
	it.index++
	return value
}

type networkIterator struct {
	items []*libbox.NetworkInterface
	index int
}

func (it *networkIterator) HasNext() bool { return it.index < len(it.items) }
func (it *networkIterator) Next() *libbox.NetworkInterface {
	if !it.HasNext() {
		return nil
	}
	value := it.items[it.index]
	it.index++
	return value
}

type harmonyPlatform struct{}

var _ libbox.PlatformInterface = (*harmonyPlatform)(nil)

func (p *harmonyPlatform) LocalDNSTransport() libbox.LocalDNSTransport { return nil }
func (p *harmonyPlatform) UsePlatformAutoDetectInterfaceControl() bool { return false }
func (p *harmonyPlatform) AutoDetectInterfaceControl(fd int32) error   { return nil }

func (p *harmonyPlatform) OpenTun(options libbox.TunOptions) (int32, error) {
	mu.Lock()
	defer mu.Unlock()
	if tunFD < 0 {
		return -1, errors.New("VPN Direct: TUN fd is not set")
	}
	return int32(tunFD), nil
}

func (p *harmonyPlatform) UseProcFS() bool { return false }
func (p *harmonyPlatform) FindConnectionOwner(ipProtocol int32, sourceAddress string, sourcePort int32, destinationAddress string, destinationPort int32) (*libbox.ConnectionOwner, error) {
	return nil, errors.New("connection owner lookup is not supported on HarmonyOS")
}
func (p *harmonyPlatform) StartDefaultInterfaceMonitor(listener libbox.InterfaceUpdateListener) error {
	return nil
}
func (p *harmonyPlatform) CloseDefaultInterfaceMonitor(listener libbox.InterfaceUpdateListener) error {
	return nil
}

func (p *harmonyPlatform) GetInterfaces() (libbox.NetworkInterfaceIterator, error) {
	interfaces, err := net.Interfaces()
	if err != nil {
		return nil, err
	}
	result := make([]*libbox.NetworkInterface, 0, len(interfaces))
	for _, iface := range interfaces {
		name := strings.ToLower(iface.Name)
		if name == "lo" || strings.Contains(name, "vpn") || strings.Contains(name, "tun") {
			continue
		}
		addresses := make([]string, 0)
		for _, address := range iface.Addrs() {
			prefix, parseErr := netip.ParsePrefix(address.String())
			if parseErr != nil || prefix.Addr().IsLinkLocalUnicast() {
				continue
			}
			addresses = append(addresses, prefix.String())
		}
		result = append(result, &libbox.NetworkInterface{
			Index:     int32(iface.Index),
			MTU:       int32(iface.MTU),
			Name:      iface.Name,
			Addresses: &stringIterator{items: addresses},
			Flags:     int32(iface.Flags),
			Type:      libbox.InterfaceTypeOther,
			DNSServer: &stringIterator{},
			Metered:   false,
		})
	}
	return &networkIterator{items: result}, nil
}

func (p *harmonyPlatform) UnderNetworkExtension() bool { return false }
func (p *harmonyPlatform) IncludeAllNetworks() bool    { return false }
func (p *harmonyPlatform) ReadWIFIState() *libbox.WIFIState { return nil }
func (p *harmonyPlatform) ClearDNSCache() {}
func (p *harmonyPlatform) SendNotification(notification *libbox.Notification) error { return nil }
func (p *harmonyPlatform) StartNeighborMonitor(listener libbox.NeighborUpdateListener) error { return nil }
func (p *harmonyPlatform) CloseNeighborMonitor(listener libbox.NeighborUpdateListener) error { return nil }
func (p *harmonyPlatform) RegisterMyInterface(name string) {}
func (p *harmonyPlatform) UsePlatformShell() bool { return false }
func (p *harmonyPlatform) CheckPlatformShell() error { return nil }
func (p *harmonyPlatform) OpenShellSession(user *libbox.PlatformUser, command string, environ libbox.StringIterator, term string, rows int32, cols int32) (libbox.ShellSession, error) {
	return nil, errors.New("shell is not supported on HarmonyOS")
}
func (p *harmonyPlatform) LookupUser(username string) (*libbox.PlatformUser, error) { return nil, os.ErrNotExist }
func (p *harmonyPlatform) LookupSFTPServer() (string, error) { return "", os.ErrNotExist }
func (p *harmonyPlatform) ReadSystemSSHHostKey() (string, error) { return "", os.ErrNotExist }
func (p *harmonyPlatform) TailscaleHostname() string { return "" }
func (p *harmonyPlatform) UsePlatformBridge() bool { return false }
func (p *harmonyPlatform) CreateBridge(options *libbox.BridgeOptions) (libbox.BridgeSession, error) {
	return nil, errors.New("bridge is not supported on HarmonyOS")
}

func publishState(path string, state string, message string) {
	if path == "" {
		return
	}
	payload := struct {
		State   string `json:"state"`
		Message string `json:"message,omitempty"`
		At      int64  `json:"at"`
	}{State: state, Message: message, At: time.Now().UnixMilli()}
	data, err := json.Marshal(payload)
	if err != nil {
		return
	}
	tmp := path + ".tmp"
	if err = os.WriteFile(tmp, data, 0o600); err != nil {
		return
	}
	_ = os.Rename(tmp, path)
}

//export vpndirect_harmony_start
func vpndirect_harmony_start(fd C.int, profile *C.char) C.int {
	mu.Lock()
	defer mu.Unlock()

	if service != nil {
		return -114
	}
	if fd < 0 || profile == nil {
		return -22
	}

	envelope := C.GoString(profile)
	var metadata harmonyProfile
	if err := json.Unmarshal([]byte(envelope), &metadata); err != nil || metadata.StatePath == "" || metadata.SingBoxConfig == "" {
		return -22
	}
	if !strings.Contains(metadata.SingBoxConfig, `"inbounds"`) {
		publishState(metadata.StatePath, stateFailed, "sing-box config has no inbounds")
		return -22
	}

	statePath = metadata.StatePath
	tunFD = int(fd)
	publishState(statePath, stateConnecting, "")

	instance, err := libbox.NewService(metadata.SingBoxConfig, &harmonyPlatform{})
	if err != nil {
		tunFD = -1
		publishState(statePath, stateFailed, err.Error())
		return -22
	}
	if err = instance.Start(); err != nil {
		_ = instance.Close()
		tunFD = -1
		publishState(statePath, stateFailed, err.Error())
		return -5
	}

	service = instance
	publishState(statePath, stateConnected, "")
	return 0
}

//export vpndirect_harmony_stop
func vpndirect_harmony_stop() C.int {
	mu.Lock()
	defer mu.Unlock()

	if service == nil {
		if statePath != "" {
			publishState(statePath, stateDisconnected, "")
		}
		tunFD = -1
		return 0
	}

	publishState(statePath, stateDisconnecting, "")
	err := service.Close()
	service = nil
	tunFD = -1
	publishState(statePath, stateDisconnected, "")
	if err != nil {
		publishState(statePath, stateFailed, err.Error())
		return -5
	}
	return 0
}

func main() {}
