# VPN Direct — HarmonyOS Pixel / Flow Audit

Scope: `harmony-os-app` only. iOS reference: `ApplicationLibrary/Views/DirectUI` at commit `42b4fc8694e8145e5e3188857be4beffe58ace95`.

## 1. Global visual contract

| Token | iOS reference | Harmony target |
|---|---:|---:|
| Paper | `#EDF0E8` | `#EDF0E8` |
| Ink | `#141714` | `#141714` |
| Panel | `#30362E` | `#30362E` |
| Muted | `#7A8075` | `#7A8075` |
| Hairline | black 14% | `#24000000` |
| Acid | `#A8F069` | `#A8F069` |
| Green | `#2E8C4F` | `#2E8C4F` |
| Danger | `#D13D33` | `#D13D33` |
| Dial blue | RGB 71/140/250 | `#478CFA` |
| Dial off | white 82% | `#D1FFFFFF` |
| Field fill | white 45% | `#73FFFFFF` |
| Selected wash | acid 14% | `#24A8F069` |
| Page top | 24 | 24 |
| Horizontal inset | 20 | 20 |
| App bar | 58 | 58 |
| Tab bar | 46 | 46 |
| Small control | 47 | 47 |
| Server row | 58 | 58 |
| Dial frame | 264×290 | 264×290 |
| Dial inner | 180×180 | 180×180 |
| Profile hero | 116 | 116 |
| Profile avatar | 62×62 | 62×62 |
| Profile stats | 76 | 76 |
| Profile settings row | 67 | 67 |
| Utility row | ≥64 | ≥64 |
| Auth primary CTA | 52 | 52 |
| Search | 44 | 44 |
| Auto location row | 76 | 76 |
| Sheet corner radius | 0 | 0 |

No rounded card language is permitted in the Direct visual system. Borders are flat rectangles and hairlines.

## 2. Typography contract

- Micro labels: 9pt semibold/bold, monospaced, uppercase.
- Page title: 22pt semibold.
- Home status title: 27pt semibold.
- Body: 13pt regular.
- Secondary: 12pt.
- Server title: 14pt semibold.
- Display dial: 40pt medium.
- Profile hero title: 19pt semibold.
- Profile utility title: 13pt semibold.
- Profile settings title: 14pt semibold.
- Telemetry value: 10.5pt semibold monospaced.
- Telemetry label: 6.5pt bold monospaced.
- Weight 600 is the Harmony representation of iOS semibold.

## 3. Screen-by-screen audit

### Home

- Paper background fills the viewport.
- 58pt app-bar reservation.
- 24pt top page inset.
- Status block uses 4pt accent rail, 32pt high; title/subtitle stack is 10pt left from rail.
- Report action is right aligned and uses the native arrow-up-right icon.
- Mode row is 30pt high, 10pt horizontal padding, 1pt hairline.
- Dial is 264×290; ring stroke is 2pt; inner dial is 180×180; needle is 3×26 at y=-78 and rotates ±132°.
- Needle transition is 550ms ease-in-out to match iOS.
- Server row is 58pt with 28×20 flag, 20pt page inset, top/bottom hairlines.
- Telemetry footer is 50pt high with 1pt vertical separators and 28pt separator height.
- Imported-subscription controls remain hidden unless explicitly enabled by the app shell; no Free/Premium UI is shown.

### Locations

- Kicker/title/subtitle use Direct page typography.
- Search is 44pt high, 13pt horizontal inset inside the field and 20pt page margins.
- Tabs are flat, no radius; selected state is a 2pt bottom rule.
- Auto row is 76pt.
- Location flag sizes: 36×24 for the selected/large presentation and 30×20 for compact rows.
- Selected row uses acid-selected 14% wash and a 1pt hairline.
- Live latency is populated only when a real host is available; unavailable latency is `—` rather than fabricated.

### Server picker

- Full-screen/sheet content uses the flat Direct sheet language.
- Header: 28pt top inset, 20pt horizontal inset.
- Search 44pt.
- Segmented tabs: `Все / Избранное / Недавние`.
- Auto route precedes normal locations.
- Favorites/recent state is persisted.
- Selection writes the real `VpnServerSelection` state and closes the picker.
- No synthetic ping/load values are displayed.

### Profile

- Page heading: 24pt-equivalent Harmony visual stack anchored to the 20pt page inset.
- Hero: 116pt high, 16pt internal horizontal padding, 62pt avatar.
- Hero is backed by actual account/session state; no fake account ID.
- Subscription count is `01/00` from the real subscription state.
- Device count is sourced from the backend device list; unavailable backend data yields `00`, not a fabricated device count.
- Protected time is based on actual `vpn_connected_at`.
- Utility rows are ≥64pt with 42×42 marks and 1pt bottom hairlines.
- Settings rows are exactly 67pt.
- Legal rows are flat and use 1pt bottom hairlines.

### Management

- Uses `SESSION_HAS_SUBSCRIPTION` + `SESSION_PLAN_NAME`; account display name is never treated as a plan.
- Active plan hero uses flat ink panel and acid status.
- Empty state shows no subscription rather than Free/Premium entitlement language.
- Imported subscriptions remain separate from the native Direct plan.
- Add-subscription CTA is 46pt.

### Subscription picker

- Native VPN Direct subscription is always first.
- Imported URLs/configs follow it.
- Active state is driven by session/import state.
- No fake price, transaction, or entitlement is generated when backend data is absent.
- Visual hierarchy follows the iOS Direct subscription sheet: kicker → title → subtitle → primary Direct block → imported rows → add CTA.

### Plans

Periods are exactly: **30 / 90 / 180 / 270 / 365 days** = **1 / 3 / 6 / 9 / 12 months**.

Fallback catalog:
- START — 100 GB — 1 device.
- PLUS — 300 GB — 3 devices — `ПОПУЛЯРНЫЙ`.
- PRO — 700 GB — 5 devices.
- MAX — 2 TB — 10 devices.
- ULTRA — unlimited — 20 devices.

Prices remain `—` until a real catalog/quote is supplied by the backend. This is intentional and prevents fake commerce state.

### Constructor

- Sections: `Срок`, `Устройства`, `Трафик`.
- Constructor options: 7 / 30 / 90 / 180 / 365 days; 1 / 3 / 5 / 10 / 20 devices; 100 / 300 / 700 / 2000 / unlimited GB.
- Price is a backend quote only.
- Summary is derived from current constructor state.

### Authentication

Flows covered: login, email code, code verification, registration, recovery, bot, phone, phone code, success.

- Primary control height: 52pt.
- Auth brand area: 52×42.
- Flat fields/buttons; no rounded Material styling.
- Apple/Google are fail-closed when the provider is not connected; no fake login success is emitted.
- Account/session state is updated only after backend success.

### Advanced settings

Settings families covered by the Direct flow model:
- Security
- Connection
- Diagnostics
- Activity / server history
- System settings
- Application settings
- Core settings
- Tunnel settings
- On-demand settings
- About
- Service log

Shared visual rules: flat sheet/page, 20pt horizontal inset, 9pt monospaced section labels, 1pt hairlines, 0pt radius, no Material cards.

### Payment / balance / utilities

- Payment screens do not invent transaction results.
- Balance top-up exposes only selectable amounts until the backend/store adapter is connected.
- Waiting/processing/success/error are separate states and must be driven by checkout status.
- Devices/payments/promocode/support remain backend-driven.

### Privacy disclosure / first Connect

- Disclosure must appear **before the first VPN connection**, not on app launch.
- Accept must persist and only then permit the VPN start.
- Decline must leave the VPN disconnected.
- The disclosure must never be duplicated by both Index and AppShell.

## 4. Flow audit

| Flow | Source of truth | Expected presentation | State safety |
|---|---|---|---|
| Home → Connect | real VPN runtime | main page | fail closed without profile |
| Home → Server | server picker | sheet | real selection |
| Home → Report | connection report | sheet | real runtime data |
| Home → Profiles | profile picker | sheet | real profile data |
| Locations → select | location catalog | page | writes selection |
| Management → Plans | plan catalog | detail | no fake price |
| Management → Constructor | constructor | detail | no fake quote |
| Profile → Auth | auth flow | detail/sheet parity | backend only |
| Profile → Settings | settings flow | detail/sheet parity | no fake toggles |
| Subscription → imported | imported store | picker | active state persisted |
| Plan → Payment | checkout | detail | real checkout only |
| Payment → Success | checkout status | detail | backend-confirmed only |

## 5. Pixel-level rules that must not regress

1. No corner radius on Direct cards, fields, rows, sheets, CTA blocks, or avatars.
2. No emoji used for flags or system icons.
3. No Unicode arrows/checkmarks where a `DirectIcon` asset exists.
4. No fake prices, fake account IDs, fake latency, fake device counts, or fake subscription state.
5. All 1pt rules use the Direct hairline color.
6. All page content respects the 20pt horizontal inset unless a component explicitly uses the documented full-bleed geometry.
7. All Direct micro labels are monospaced and uppercase.
8. iOS semibold maps to Harmony numeric weight 600.
9. Bottom sheets use medium/large detents, visible drag bar, and zero corner radius where Harmony supports the equivalent.
10. VPN runtime status is the source of truth for Home/Profile connection state.

## 6. Remaining device-level verification

Source-level geometry and flow parity can be audited from the repository. True **pixel-for-pixel verification** additionally requires screenshots rendered on the same HarmonyOS device resolution/density as the target build and comparison against iOS reference screenshots at the corresponding logical dimensions. This repository audit therefore treats every numeric token as a source-level acceptance criterion; final visual sign-off requires rendered screenshot diffing on-device.
