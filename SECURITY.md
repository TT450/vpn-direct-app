# Security Policy

## Supported versions

Security fixes are accepted against the current `main` branch of this repository (VPN Direct Apple client + Core 0.1 scripts).

## Reporting a vulnerability

Please **do not** open a public GitHub issue for unfixed security problems.

Email the maintainers using a private channel associated with the VPN Direct / TheTochka project, or open a **private** security advisory on GitHub if enabled for this repository.

Include:

- Affected component (app, Extension, Libbox build, parser)
- Steps to reproduce
- Impact assessment
- Whether a fix is already proposed

We aim to acknowledge reports within a reasonable time and coordinate disclosure after a fix or mitigation is available.

## Scope notes

- Misconfiguration of third-party VPN servers is out of scope
- Issues that only affect outdated / unreproducible Libbox binaries without source pins should include `core/VERSION` and build tags
