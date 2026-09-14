# TestFlight — VPN Direct

How to install beta builds and invite people. **No signing secrets belong in this repo.**

## Links

| | |
| --- | --- |
| App Store (public) | https://apps.apple.com/app/id6807402257 |
| TestFlight (public join) | [Join on TestFlight](https://testflight.apple.com/join/yfCEbunt) |
| GitHub releases | https://github.com/TT450/vpn-direct-app/releases |
| Latest notes | [`WHATS_NEW.md`](../WHATS_NEW.md) |

**Public join link:** https://testflight.apple.com/join/yfCEbunt

## Current beta

| Field | Value |
| --- | --- |
| Marketing version | **1.0.11** |
| Build | **111** (login errors + legal / account deletion) |
| Bundle ID | `com.vpndirect.vpndirectapp` |
| GitHub tag | [`v1.0.11.111`](https://github.com/TT450/vpn-direct-app/releases/tag/v1.0.11.111) |

Prefer **111+**. Older builds may still appear in history.

## How to add testers (you / App Store Connect)

Use [App Store Connect](https://appstoreconnect.apple.com) → **Apps** → **VPN Direct** → **TestFlight**.

### A) Internal testing (fastest for your team)

1. Open **Internal Testing**.
2. Select the group (or create one).
3. **Testers** → add Apple IDs that are already **Users** of your App Store Connect team (Users and Access).
4. Assign the latest build (1.0.11 / **111+**).
5. Testers install the **TestFlight** app and accept the invite email / notification.

Limits: up to **100** Internal testers; they must be on your ASC team.

### B) External testing (friends, public beta)

1. Open **External Testing** → create a group (e.g. `Public Beta`).
2. Add the build; the first External build may need a short **Beta App Review**.
3. **Testers** → add emails, or turn on **Public Link** and share `https://testflight.apple.com/join/XXXX`.
4. Optional: set tester count cap; revoke the public link anytime.

Limits: up to **10_000** External testers per app (Apple’s current cap). Public link is the easiest way to “add everyone”.

### C) What testers need

1. iPhone with a recent iOS (home widgets need iOS 17+; Control Center toggle needs iOS 18+).
2. [TestFlight](https://apps.apple.com/app/testflight/id899247664) installed.
3. Invite accepted with the **same Apple ID** used on the device.

### D) Sandbox IAP (credits)

TestFlight purchases use Apple Sandbox + RevenueCat. Packs: `direct.credits.4.99` … `199.99`.

1. Install **111+** from TestFlight.
2. Sign in to VPN Direct account.
3. Buy a credit pack — Apple Sheet is sandbox (no real charge with Sandbox Apple ID).
4. Balance should credit after RC verification on the Direct ledger.

## Engineering upload (maintainers)

Release lane (credentials via local env / gitignored `.p8` only — never commit):

```bash
# Required env: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH, APP_STORE_APP_ID, FASTLANE_TEAM_ID
# Optional: TESTFLIGHT_CHANGELOG
fastlane ios release
```

See `fastlane/SECRETS.example.md`. App Store provisioning profiles for app + extensions must exist before export (widget profile needs Network Extension for in-extension tunnel control).

## Support

- Product / bot: [Telegram - vpndirectbot](https://t.me/vpndirectbot)
- Source issues: [GitHub Issues](https://github.com/TT450/vpn-direct-app/issues)
