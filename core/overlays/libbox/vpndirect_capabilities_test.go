package libbox

import (
	"encoding/json"
	"testing"
)

func TestVPNDirectCapabilityJSONMieruFalseByDefault(t *testing.T) {
	raw := VPNDirectCapabilityJSON()
	var doc map[string]any
	if err := json.Unmarshal([]byte(raw), &doc); err != nil {
		t.Fatalf("CapabilityJSON unmarshal: %v", err)
	}
	if magic, _ := doc["magic"].(string); magic != vpnDirectCoreMagicValue {
		t.Fatalf("magic=%v want %s", doc["magic"], vpnDirectCoreMagicValue)
	}
	if mieru, _ := doc["mieru"].(bool); mieru {
		t.Fatalf("top-level mieru must be false until runtime is ported")
	}
	protocols, _ := doc["protocols"].(map[string]any)
	mieruObj, _ := protocols["mieru"].(map[string]any)
	if supported, _ := mieruObj["supported"].(bool); supported {
		t.Fatalf("protocols.mieru.supported must be false until runtime is ported")
	}
	if VPNDirectSupportsMieru() {
		t.Fatalf("VPNDirectSupportsMieru must be false without with_mieru")
	}
}

func TestVPNDirectCapabilityJSONHasVLESSTree(t *testing.T) {
	raw := VPNDirectCapabilityJSON()
	var doc map[string]any
	if err := json.Unmarshal([]byte(raw), &doc); err != nil {
		t.Fatalf("CapabilityJSON unmarshal: %v", err)
	}
	protocols, _ := doc["protocols"].(map[string]any)
	vless, _ := protocols["vless"].(map[string]any)
	if vless == nil {
		t.Fatal("missing protocols.vless")
	}
	transports, _ := vless["transports"].([]any)
	if len(transports) == 0 {
		t.Fatal("protocols.vless.transports empty")
	}
	security, _ := vless["security"].([]any)
	if len(security) == 0 {
		t.Fatal("protocols.vless.security empty")
	}
}
