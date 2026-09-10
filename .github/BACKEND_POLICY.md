# Backend material is not allowed in this GitHub repository

This file is the GitHub-side rule. Cursor has the same policy in `.cursor/rules/no-backend-github.mdc`.

## Forbidden (local / server only)

Do not commit, push, or open a PR that includes:

- Backend patch trees, ops folders, TZ/SoW/runbooks
- Private API clients, host installers, endpoint catalogs
- Real backend hostnames, IPs, admin secret paths, panel URLs
- Product `/api/v1` routes, webhook secrets, payment keys, SSH keys, DB dumps
- nginx/admin patch modules and `mobile_api` payloads

Those files belong in `.gitignore` (see the “Backend / Direct API / ops” block). Never `git add -f`.

## Allowed

- iOS/macOS app UI without private API/hooks/host files
- Empty public runtime facade (no real hosts or routes)
- Product docs that do not describe servers, APIs, or credentials

## Review checklist

CI workflow `no-backend.yml` fails the job if known private paths are tracked. That is not a substitute for review: also reject any diff that names backend hosts, IPs, admin paths, or private API routes.
