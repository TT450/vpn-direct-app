package main

/*
#cgo CFLAGS: -D_GNU_SOURCE
#include <stdint.h>
*/
import "C"

import (
	"errors"
	"sync"
	"unsafe"

	"github.com/sagernet/sing-box/experimental/libbox"
)

var (
	mu      sync.Mutex
	service *libbox.BoxService
	tunFD   int32 = -1
)

type platformAdapter struct {
	fd int32
}

func (p *platformAdapter) LocalDNSTransport() libbox.LocalDNSTransport { return nil }
func (p *platformAdapter) UsePlatformAutoDetectInterfaceControl() bool { return false }
func (p *platformAdapter) AutoDetectInterfaceControl(fd int32) error { return nil }
func (p *platformAdapter) OpenTun(options libbox.TunOptions) (int32, error) { return p.fd, nil }
func (p *platformAdapter) WriteLog(message string) {}
func (p *platformAdapter) UseProcFS() bool { return false }
func (p *platformAdapter) FindConnectionOwner(ipProtocol int32, sourceAddress string, sourcePort int32, destinationAddress string, destinationPort int32) (*libbox.ConnectionOwner, error) {
	return nil, errors.New("HarmonyOS platform process ownership is not implemented")
}
func (p *platformAdapter) StartDefaultInterfaceMonitor(listener libbox.InterfaceUpdateListener) error { return nil }
func (p *platformAdapter) CloseDefaultInterfaceMonitor(listener libbox.InterfaceUpdateListener) error { return nil }
func (p *platformAdapter) GetInterfaces() (libbox.NetworkInterfaceIterator, error) {
	return nil, errors.New("HarmonyOS interface enumeration is not implemented")
}
func (p *platformAdapter) UnderNetworkExtension() bool { return false }
func (p *platformAdapter) IncludeAllNetworks() bool { return true }
func (p *platformAdapter) ReadWIFIState() *libbox.WIFIState { return nil }
func (p *platformAdapter) ClearDNSCache() {}
func (p *platformAdapter) SendNotification(notification *libbox.Notification) error { return nil }
func (p *platformAdapter) CancelNotification(identifier string, typeID int32) error { return nil }
func (p *platformAdapter) StartNeighborMonitor(listener libbox.NeighborUpdateListener) error { return nil }
func (p *platformAdapter) CloseNeighborMonitor(listener libbox.NeighborUpdateListener) error { return nil }
func (p *platformAdapter) RegisterMyInterface(name string) {}
func (p *platformAdapter) UsePlatformShell() bool { return false }
func (p *platformAdapter) CheckPlatformShell() error { return errors.New("HarmonyOS platform shell is unavailable") }
func (p *platformAdapter) OpenShellSession(user *libbox.PlatformUser, command string, environ libbox.StringIterator, term string, rows int32, cols int32) (libbox.ShellSession, error) {
	return nil, errors.New("HarmonyOS platform shell is unavailable")
}
func (p *platformAdapter) LookupUser(username string) (*libbox.PlatformUser, error) {
	return nil, errors.New("HarmonyOS platform users are unavailable")
}
func (p *platformAdapter) LookupSFTPServer() (string, error) { return "", errors.New("HarmonyOS SFTP is unavailable") }
func (p *platformAdapter) ReadSystemSSHHostKey() (string, error) { return "", errors.New("HarmonyOS SSH host key is unavailable") }
func (p *platformAdapter) TailscaleHostname() string { return "" }
func (p *platformAdapter) UsePlatformBridge() bool { return false }
func (p *platformAdapter) CreateBridge(options *libbox.BridgeOptions) (libbox.BridgeSession, error) {
	return nil, errors.New("HarmonyOS bridge is unavailable")
}

//export vpndirect_harmony_start
func vpndirect_harmony_start(tunFD C.int, profileJSON *C.char) C.int {
	mu.Lock()
	defer mu.Unlock()

	if service != nil {
		return C.int(-114)
	}
	if tunFD < 0 || profileJSON == nil {
		return C.int(-22)
	}

	config := C.GoString(profileJSON)
	if config == "" {
		return C.int(-22)
	}
	if err := libbox.CheckConfig(config); err != nil {
		return C.int(-1001)
	}

	adapter := &platformAdapter{fd: int32(tunFD)}
	instance, err := libbox.NewService(config, adapter)
	if err != nil {
		return C.int(-1002)
	}
	if err = instance.Start(); err != nil {
		_ = instance.Close()
		return C.int(-1003)
	}

	service = instance
	tunFD = C.int(tunFD)
	return 0
}

//export vpndirect_harmony_stop
func vpndirect_harmony_stop() C.int {
	mu.Lock()
	defer mu.Unlock()

	if service == nil {
		return 0
	}
	if err := service.Close(); err != nil {
		return C.int(-1004)
	}
	service = nil
	tunFD = -1
	return 0
}

func main() {
	// Required for -buildmode=c-shared; exported C ABI is used by N-API.
	_ = unsafe.Pointer(nil)
}
