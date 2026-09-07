# VLESS

- Upstream: Xray-core, sing-box / sing-box-lx  
- URI: `vless://` — VPN Direct `VLESSConfigBuilder` + `VLESSShareLinkParser`  
- Transports: tcp/ws/grpc/httpupgrade/http/xhttp (capability-gated)  
- Security: none/tls/reality; encryption/PQ as extensible string  
- **Unknown query keys:** fail closed if connection-critical (`CompatibilityFieldPolicy`)  
- Xray JSON: `XrayVLESSConverter` + stream extras → `rawExtensions`  
- Status: parser+runtime; interop/device planned  
