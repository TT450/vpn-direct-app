/**
 * Tracked public stub (same content as committed DirectBackendLocal.ets).
 *
 * Private machines: replace DirectBackendLocal.ets with a registration that imports
 * DirectBackendHooks.local and assigns DirectBackendRuntime.localInstaller, then:
 *   git update-index --skip-worktree harmony/entry/src/main/ets/backend/DirectBackendLocal.ets
 *
 * Never commit a Local.ets that imports *.local.ets.
 */
export function ensureLocalBackendRegistered(): void {
  // Public no-op. Private override registers DirectBackendRuntime.localInstaller.
}
