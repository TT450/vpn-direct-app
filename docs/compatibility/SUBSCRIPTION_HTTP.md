# Subscription HTTP contract

## Client request (VPN Direct)

Always Happ-first for remote subscription fetch (`SubscriptionClientIdentity`).

| Header | Required | Notes |
| --- | --- | --- |
| `User-Agent` | yes | `Happ/3.13.0` first; brand UAs fallback only |
| `X-HWID` / `x-hwid` | yes | Remnawave `/^[a-zA-Z0-9=-]{10,64}$/`; Keychain-stable |
| `X-Device-OS` | yes | |
| `X-Ver-OS` | yes | |
| `X-Device-Model` | yes | |
| `X-Device-Locale` | yes | |
| `Accept` | yes | `text/plain, application/json, */*` |
| `Accept-Encoding` | yes | `gzip, deflate, br` |
| `If-None-Match` / `If-Modified-Since` | optional | when `cachedETag` / `cachedLastModified` passed to `SubscriptionHTTP.fetch` |

Redirects: follow 301/302/307/308 via URLSession defaults.

## Response headers to capture

| Header | Source panels | Stored in |
| --- | --- | --- |
| `Subscription-Userinfo` | 3x-ui, Remnawave, Marzban family, Hiddify | traffic/expiry |
| `Profile-Title` | 3x-ui (+ base64:), Remnawave | title |
| `Profile-Update-Interval` | 3x-ui | updateIntervalHours |
| `Profile-Web-Page-Url` | 3x-ui | profileWebPageURL |
| `Support-Url` | 3x-ui | supportURL |
| `Announce` | 3x-ui (+ base64:) | announce |
| `Routing` / `Routing-Enable` | 3x-ui Happ advanced | routingRules / routingEnabled |
| `x-hwid-*` | Remnawave | device limit state |
| `x-provider-id` | Remnawave response modifications | provider hint |
| `ETag` / `Last-Modified` | generic | cache (`SubscriptionMetadata.etag` / `lastModified`; 304 → `SubscriptionHTTP.ConditionalNotModified`) |
| `Content-Disposition` | generic | title fallback |
| `Content-Type` | all | detector hint |

## Remnawave Response Rules (research pin)

`responseType`: BROWSER, BLOCK, STATUS_CODE_404, STATUS_CODE_451, SOCKET_DROP, XRAY_JSON, XRAY_BASE64, MIHOMO, STASH, CLASH, SINGBOX.

Conditions match request headers (UA, x-device-os, …). Format is **not** chosen by domain name.

## 3x-ui format selection

Path-based: raw/base64 list vs JSON path vs Clash path — not UA-only.

## Encoding

UTF-8 preferred; ISO-8859-1 fallback exists; strip BOM in detector; base64 URI lists; `base64:` profile titles.
