# Public-derived sanitized fixtures

Curated copies of interesting real-world public configs, rewritten so they are safe to commit and stable for CI.

## Sanitize rules

1. **Hosts / IPs** → documentation ranges only (`203.0.113.x` IPv4, `2001:db8::/32` IPv6). Never keep live endpoints.
2. **UUID / passwords / tokens / keys** → deterministic fake values (obviously non-secret placeholders).
3. **SNI / hostnames** → `example.com` / `example.net` (or similarly reserved names).
4. **Preserve structure** — transport (`type=`), security (`security=`), flow, encryption, method, ALPN, path shape, and field presence stay meaningful for parser regression.
5. **Attribution** — each sample directory includes `SOURCE.md` with upstream repo, retrieval date, and notes. Do not paste credentialed URIs into `SOURCE.md`.
6. **Volatility** — these fixtures are golden; live public pools remain volatile and must not gate required CI when empty/404.

## Layout

```text
tests/fixtures/public-derived/
  README.md
  sample-vless-tcp/
    SOURCE.md
    sample.uri
```

Add new directories when auto-discovery finds connection-critical unknowns; prefer fail-closed fixtures under `unknown-critical/` when support is deferred.
