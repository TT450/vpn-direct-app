#include <cstdint>

namespace vpndirect::harmony {

// Native ABI boundary intentionally starts minimal. The actual VPNDirectCore
// shared library and tun2socks implementation will be integrated after a
// real HarmonyOS toolchain/device spike. Keeping the boundary explicit avoids
// leaking platform-specific types into the portable core.

struct CoreHandle {
    void* value = nullptr;
};

using StartFn = int (*)(const char* config_json, int tun_fd);
using StopFn = int (*)();
using VersionFn = const char* (*)();

} // namespace vpndirect::harmony
