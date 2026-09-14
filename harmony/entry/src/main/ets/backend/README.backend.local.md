# Direct backend (Harmony) — local only

Public clones ship an empty injectable runtime and a tracked empty `DirectBackendLocal.ets`.
Real HTTP clients stay in gitignored `*.local.ets` files.

## How wiring works

1. `DirectBackendRuntime.localInstaller` defaults to `null` (public no-op `warmUp`).
2. Tracked `DirectBackendLocal.ets` exports `ensureLocalBackendRegistered()` with no private imports.
3. On a private machine, replace `DirectBackendLocal.ets` so it assigns `localInstaller` from
   `DirectBackendHooks.local`, then hide the change from git:
   ```bash
   git update-index --skip-worktree harmony/entry/src/main/ets/backend/DirectBackendLocal.ets
   ```
4. `EntryAbility` always imports Local (so the module loads) and calls `warmUp`.

## First build / restore empty stub

```bash
bash harmony/scripts/ensure_local_backend.sh
```

Or copy:

```bash
cp harmony/entry/src/main/ets/backend/DirectBackendLocal.example.ets \
   harmony/entry/src/main/ets/backend/DirectBackendLocal.ets
```

## Do not commit

- `DirectBackendAPI.local.ets`
- `DirectBackendHooks.local.ets`
- any other `*.local.ets`
- anything under `backend_private/`
- `direct_backend.local.json`
- a `DirectBackendLocal.ets` that imports `*.local.ets` (keep the public empty stub in the index)
