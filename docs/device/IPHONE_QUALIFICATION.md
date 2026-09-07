# iPhone qualification matrix

Do not mark PROTOCOL_MATRIX rows `tested` until this checklist is filled for a Core SHA.

## How to install Wi‑Fi Debug + fill this checklist

1. Connect the iPhone to the same LAN as the Mac; enable Developer Mode + wireless debugging pairing in Xcode / `devicectl`.
2. Build: `xcodebuild build -scheme SFI -configuration Debug -destination 'generic/platform=iOS'`.
3. Install the product app (`sing-box.app` / bundle `com.vpndirect.vpndirectapp`) via `devicectl device install app`.
4. Import a **battle** fixture from `interop/*/run.sh` (env-injected keys — never commit secrets).
5. Run the rows below; record RSS from Xcode Instruments / OS Logs. **Do not invent RSS numbers.**
6. Attach notes + Core SHA under `interop/<family>/evidence/` before flipping matrix Interop/Status to `tested`.

| Check | Pass | Notes / evidence path |
| --- | --- | --- |
| Fresh install | | |
| Upgrade from previous build | | |
| Connect / disconnect ×100 | | |
| Server switch | | |
| Profile switch | | |
| Wi‑Fi → LTE | | |
| LTE → Wi‑Fi | | |
| Airplane mode toggle | | |
| Sleep / wake | | |
| Background | | |
| Extension restart | | |
| DNS through tunnel | | |
| IPv4 | | |
| IPv6 | | |
| RSS startup | | |
| RSS connected idle | | |
| RSS under traffic | | |
| Peak RSS | | |
| CPU idle / load | | |
| Connect latency | | |

Core SHA: _______________  
Device: _______________  
Date: _______________
