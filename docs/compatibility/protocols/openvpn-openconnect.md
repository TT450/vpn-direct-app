# OpenVPN / OpenConnect

## OpenVPN

- Core endpoint: `type: "openvpn-client"` (`with_openvpn`)
- Import: classic `.ovpn` / client `.conf` via `OpenVPNConfigAdapter`
- UI: Import from File (`.ovpn`, `.conf`, plain text)

## OpenConnect

- Core endpoint: `type: "openconnect"` (`with_openconnect`)
- Import: sing-box JSON, or AnyConnect-ish XML / key=value text via `OpenConnectConfigAdapter`
- Flavors: `anyconnect`, `gp`, `fortinet`, … (Core enum)

Both land in the graph `endpoints` array (same selector/urltest membership rules as WireGuard).
