/* Public weak no-op. Local DirectBackendHooks.swift provides a strong @_cdecl
 * symbol with the same name that installs real backend bindings. */
__attribute__((weak))
void direct_backend_hooks_install(void) {}
