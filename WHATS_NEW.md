# What's New — VPN Direct 1.0.3

Release date: 2026-09-07  
Git tag: `v1.0.3`

## App Store / short What's New

- Subscription fetch always identifies as Happ first (Remnawave-compatible); VPN Direct UA only as fallback
- Stable device HWID stored in Keychain (keeps the same device slot across updates)
- CI fix for Network Extension profile build on GitHub Actions
- Compatibility harvest plan from TheTochka donor documented for Hysteria / balancers next

## Engineering detail

### Subscription identity (TheTochka-compatible)
- New `SubscriptionClientIdentity`: `User-Agent: Happ/3.13.0` is always first
- Brand agents (`vpndirect`, `VPN Direct/…`, `sfi/… vpndirect`) are fallbacks only when Happ response is stub/empty/unparsable
- App `HTTPClient` stays `vpndirect/1.0.0 (SFI; …)` for ruleset/update — not Happ

### HWID
- `DeviceIdentity` prefers Keychain; migrates legacy UserDefaults HWID without rotating it
- Remnawave headers unchanged: `X-HWID`, `X-Device-OS`, `X-Ver-OS`, `X-Device-Model`, `X-Device-Locale`

### CI
- Fixed `ExtensionProfile` `nonisolated deinit` (requires experimental flag on Xcode 16.4 runners)

### Next harvest (documented, not fully ported yet)
- See `docs/core/THETOCHKA_COMPATIBILITY_HARVEST.md`: Hysteria/HY2, Remnawave location urltest, balancers, cascades, XHTTP CDN quirks

See also: `CHANGELOG.md`.
