# Tailscale

Core endpoint: `type: "tailscale"` (`with_tailscale` on Darwin Libbox after rebuild).

## Import

Paste or Import from File a JSON object:

```json
{
  "type": "tailscale",
  "tag": "ts",
  "auth_key": "tskey-auth-…",
  "control_url": "https://controlplane.tailscale.com",
  "hostname": "iphone",
  "accept_routes": true
}
```

Adapter: `TailscaleConfigAdapter` → graph `endpoints`.

## Notes

- State directory / interactive OAuth UI is not required for auth-key import
- Linked Libbox must include `with_tailscale` or `LibboxCheckConfig` rejects the endpoint
