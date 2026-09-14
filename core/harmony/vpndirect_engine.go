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
	"path/filepath"
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

type interfaceMonitor struct {
	stop chan struct{}
	done chan struct{}
}

var (
	mu            sync.Mutex
	commandServer *libbox.CommandServer
	platform      *harmonyPlatform
	tunFD         = -1
	statePath     string
	setupDone     bool
	monitors      = make(map[libbox.InterfaceUpdateListener]*interfaceMonitor)
	heartbeatStop chan struct{}
	heartbeatDone chan struct{}
)

type stringIterator struct {
	items []string
	index int
}

func (it *stringIterator) Len() int32   { return int32(len(it.items)) }
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

type harmonyPlatform struct {
	fd int32
}

var (
	_ libbox.PlatformInterface    = (*harmonyPlatform)(nil)
	_ libbox.CommandServerHandler = (*harmonyPlatform)(nil)
)

func (p *harmonyPlatform) LocalDNSTransport() libbox.LocalDNSTransport { return nil }
func (p *harmonyPlatform) UsePlatformAutoDetectInterfaceControl() bool  { return false }
func (p *harmonyPlatform) AutoDetectInterfaceControl(fd int32) error    { return nil }
func (p *harmonyPlatform) OpenTun(options libbox.TunOptions) (int32, error) {
	if p.fd < 0 {
		return -1, errors.New("VPN Direct: TUN fd is not set")
	}
	return p.fd, nil
}
func (p *harmonyPlatform) UseProcFS() bool { return false }
func (p *harmonyPlatform) FindConnectionOwner(ipProtocol int32, sourceAddress string, sourcePort int32, destinationAddress string, destinationPort int32) (*libbox.ConnectionOwner, error) {
	return nil, errors.New("connection owner lookup is not supported on HarmonyOS")
}
func (p *harmonyPlatform) StartDefaultInterfaceMonitor(listener libbox.InterfaceUpdateListener) error {
	if listener == nil {
		return errors.New("nil interface listener")
	}
	mu.Lock()
	if _, exists := monitors[listener]; exists {
		mu.Unlock()
		return nil
	}
	monitor := &interfaceMonitor{stop: make(chan struct{}), done: make(chan struct{})}
	monitors[listener] = monitor
	mu.Unlock()
	go func() {
		defer close(monitor.done)
		ticker := time.NewTicker(2 * time.Second)
		defer ticker.Stop()
		lastName := ""
		for {
			name, index := defaultInterface()
			if name != "" && (name != lastName || lastName == "") {
				listener.UpdateDefaultInterface(name, int32(index), false, false)
				lastName = name
			}
			select {
			case <-ticker.C:
			case <-monitor.stop:
				return
			}
		}
	}()
	return nil
}
func (p *harmonyPlatform) CloseDefaultInterfaceMonitor(listener libbox.InterfaceUpdateListener) error {
	mu.Lock()
	monitor, exists := monitors[listener]
	if exists {
		delete(monitors, listener)
	}
	mu.Unlock()
	if !exists {
		return nil
	}
	close(monitor.stop)
	<-monitor.done
	return nil
}

func defaultInterface() (string, int) {
	interfaces, err := net.Interfaces()
	if err != nil {
		return "", 0
	}
	for _, iface := range interfaces {
		name := strings.ToLower(iface.Name)
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 || strings.Contains(name, "vpn") || strings.Contains(name, "tun") {
			continue
		}
		return iface.Name, iface.Index
	}
	return "", 0
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
		addrs, addrErr := iface.Addrs()
		if addrErr != nil {
			continue
		}
		for _, address := range addrs {
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
			Gateway:   &stringIterator{},
			Metered:   false,
		})
	}
	return &networkIterator{items: result}, nil
}

func (p *harmonyPlatform) UnderNetworkExtension() bool { return false }
func (p *harmonyPlatform) IncludeAllNetworks() bool    { return false }
func (p *harmonyPlatform) ReadWIFIState() *libbox.WIFIState {
	return nil
}
func (p *harmonyPlatform) ClearDNSCache() {}
func (p *harmonyPlatform) SendNotification(notification *libbox.Notification) error {
	return nil
}
func (p *harmonyPlatform) CancelNotification(identifier string, typeID int32) error {
	return nil
}
func (p *harmonyPlatform) StartNeighborMonitor(listener libbox.NeighborUpdateListener) error {
	return nil
}
func (p *harmonyPlatform) CloseNeighborMonitor(listener libbox.NeighborUpdateListener) error {
	return nil
}
func (p *harmonyPlatform) RegisterMyInterface(name string) {}
func (p *harmonyPlatform) UsePlatformShell() bool          { return false }
func (p *harmonyPlatform) CheckPlatformShell() error       { return nil }
func (p *harmonyPlatform) OpenShellSession(user *libbox.PlatformUser, command string, environ libbox.StringIterator, term string, rows int32, cols int32) (libbox.ShellSession, error) {
	return nil, errors.New("shell is not supported on HarmonyOS")
}
func (p *harmonyPlatform) LookupUser(username string) (*libbox.PlatformUser, error) {
	return nil, os.ErrNotExist
}
func (p *harmonyPlatform) LookupSFTPServer() (string, error) { return "", os.ErrNotExist }
func (p *harmonyPlatform) ReadSystemSSHHostKey() (string, error) {
	return "", os.ErrNotExist
}
func (p *harmonyPlatform) TailscaleHostname() string { return "" }
func (p *harmonyPlatform) UsePlatformBridge() bool   { return false }
func (p *harmonyPlatform) CreateBridge(options *libbox.BridgeOptions) (libbox.BridgeSession, error) {
	return nil, errors.New("bridge is not supported on HarmonyOS")
}

func (p *harmonyPlatform) ServiceStop() error   { return nil }
func (p *harmonyPlatform) ServiceReload() error { return nil }
func (p *harmonyPlatform) GetSystemProxyStatus() (*libbox.SystemProxyStatus, error) {
	return &libbox.SystemProxyStatus{}, nil
}
func (p *harmonyPlatform) SetSystemProxyEnabled(enabled bool) error { return nil }
func (p *harmonyPlatform) TriggerNativeCrash() error {
	return errors.New("native crash is not supported on HarmonyOS")
}
func (p *harmonyPlatform) WriteDebugMessage(message string) {}
func (p *harmonyPlatform) ConnectSSHAgent() (int32, error) {
	return -1, errors.New("SSH agent is not supported on HarmonyOS")
}

func publishState(path, state, message string) {
	if path == "" {
		return
	}
	payload := struct {
		State   string `json:"state"`
		Message string `json:"message,omitempty"`
		At      int64  `json:"at"`
	}{state, message, time.Now().UnixMilli()}
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

func startHeartbeat(path string) {
	heartbeatStop = make(chan struct{})
	heartbeatDone = make(chan struct{})
	go func() {
		defer close(heartbeatDone)
		ticker := time.NewTicker(2 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				publishState(path, stateConnected, "")
			case <-heartbeatStop:
				return
			}
		}
	}()
}

func stopHeartbeat() {
	if heartbeatStop == nil {
		return
	}
	close(heartbeatStop)
	<-heartbeatDone
	heartbeatStop = nil
	heartbeatDone = nil
}

func setupLibbox(path string) error {
	if setupDone {
		return nil
	}
	base := filepath.Dir(path)
	temp := filepath.Join(base, "vpn-direct-tmp")
	if err := os.MkdirAll(temp, 0o700); err != nil {
		return err
	}
	err := libbox.Setup(&libbox.SetupOptions{
		BasePath:                base,
		WorkingPath:             base,
		TempPath:                temp,
		FixAndroidStack:         false,
		CommandServerListenPort: 0,
		Debug:                   false,
		CrashReportSource:       "vpn-direct-harmony",
		AppVersion:              "0.1.0",
		AppMarketingVersion:     "0.1.0",
		OomKillerDisabled:       true,
		PowerReportEnabled:      false,
	})
	if err != nil {
		return err
	}
	setupDone = true
	return nil
}

//export vpndirect_harmony_start
func vpndirect_harmony_start(fd C.int, profile *C.char) C.int {
	mu.Lock()
	defer mu.Unlock()

	if commandServer != nil {
		return -114
	}
	if fd < 0 || profile == nil {
		return -22
	}

	var metadata harmonyProfile
	if err := json.Unmarshal([]byte(C.GoString(profile)), &metadata); err != nil || metadata.StatePath == "" || metadata.SingBoxConfig == "" {
		return -22
	}
	if !strings.Contains(metadata.SingBoxConfig, `"inbounds"`) || !strings.Contains(metadata.SingBoxConfig, `"outbounds"`) {
		publishState(metadata.StatePath, stateFailed, "sing-box config must contain inbounds and outbounds")
		return -22
	}

	statePath = metadata.StatePath
	tunFD = int(fd)
	publishState(statePath, stateConnecting, "")

	if err := setupLibbox(statePath); err != nil {
		tunFD = -1
		publishState(statePath, stateFailed, err.Error())
		return -5
	}
	if err := libbox.CheckConfig(metadata.SingBoxConfig); err != nil {
		tunFD = -1
		publishState(statePath, stateFailed, err.Error())
		return -22
	}

	platform = &harmonyPlatform{fd: int32(tunFD)}
	server, err := libbox.NewCommandServer(platform, platform)
	if err != nil {
		platform = nil
		tunFD = -1
		publishState(statePath, stateFailed, err.Error())
		return -22
	}
	if err = server.Start(); err != nil {
		server.Close()
		platform = nil
		tunFD = -1
		publishState(statePath, stateFailed, err.Error())
		return -5
	}
	if err = server.StartOrReloadService(metadata.SingBoxConfig, &libbox.OverrideOptions{}); err != nil {
		server.Close()
		platform = nil
		tunFD = -1
		publishState(statePath, stateFailed, err.Error())
		return -5
	}

	commandServer = server
	publishState(statePath, stateConnected, "")
	startHeartbeat(statePath)
	return 0
}

//export vpndirect_harmony_stop
func vpndirect_harmony_stop() C.int {
	mu.Lock()
	server := commandServer
	path := statePath
	if server == nil {
		tunFD = -1
		platform = nil
		mu.Unlock()
		publishState(path, stateDisconnected, "")
		return 0
	}
	publishState(path, stateDisconnecting, "")
	commandServer = nil
	platform = nil
	tunFD = -1
	stopHeartbeat()
	mu.Unlock()

	_ = server.CloseService()
	server.Close()
	publishState(path, stateDisconnected, "")
	return 0
}

func main() {}
