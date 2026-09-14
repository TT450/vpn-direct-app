#include <napi/native_api.h>
#include <atomic>
#include <mutex>
#include <string>

// Platform bridge only. The actual VPN Direct Core is linked as a pinned
// native library during the HarmonyOS build; this file intentionally contains
// no private endpoints, credentials, or downloadable executable payloads.
namespace {
std::mutex g_mutex;
std::atomic<bool> g_running{false};
int g_tun_fd = -1;

// These two functions are the ABI seam to the HarmonyOS build of
// VPNDirectCore. They are deliberately declared here rather than copying the
// iOS Libbox implementation into the platform adapter.
extern "C" int vpndirect_harmony_start(int tun_fd, const char* profile_json);
extern "C" int vpndirect_harmony_stop();

napi_value Start(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value argv[2] = {nullptr, nullptr};
  napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  if (argc != 2) return nullptr;

  int32_t tun_fd = -1;
  napi_get_value_int32(env, argv[0], &tun_fd);

  size_t length = 0;
  napi_get_value_string_utf8(env, argv[1], nullptr, 0, &length);
  std::string profile(length, '\0');
  napi_get_value_string_utf8(env, argv[1], profile.data(), length + 1, &length);

  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_running.load()) return nullptr;
  const int rc = vpndirect_harmony_start(tun_fd, profile.c_str());
  if (rc == 0) {
    g_tun_fd = tun_fd;
    g_running.store(true);
  }
  napi_value result;
  napi_create_int32(env, rc, &result);
  return result;
}

napi_value Stop(napi_env env, napi_callback_info info) {
  (void)info;
  std::lock_guard<std::mutex> lock(g_mutex);
  const int rc = vpndirect_harmony_stop();
  g_tun_fd = -1;
  g_running.store(false);
  napi_value result;
  napi_create_int32(env, rc, &result);
  return result;
}
} // namespace

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
  napi_property_descriptor desc[] = {
      {"start", nullptr, Start, nullptr, nullptr, nullptr, napi_default, nullptr},
      {"stop", nullptr, Stop, nullptr, nullptr, nullptr, napi_default, nullptr},
  };
  napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
  return exports;
}
EXTERN_C_END

static napi_module g_module = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "vpndirect_core",
    .nm_priv = nullptr,
    .reserved = {0},
};

extern "C" __attribute__((constructor)) void RegisterVpndirectModule(void) {
  napi_module_register(&g_module);
}
