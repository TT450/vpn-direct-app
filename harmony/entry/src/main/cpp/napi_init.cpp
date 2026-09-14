#include <napi/native_api.h>

#include <atomic>
#include <mutex>
#include <string>

// Public platform bridge only. The actual VPN Direct Core is linked by the
// HarmonyOS Core build. No private endpoints, credentials, or downloadable
// executable payloads belong here.
namespace {
std::mutex g_mutex;
std::atomic<bool> g_running{false};
int g_tun_fd = -1;

// The Core ABI is deliberately optional at this stage. Weak symbols let the
// platform adapter build before the real ARM64 Core artifact is linked. Once
// the Core is linked, these symbols become the real implementation.
extern "C" int vpndirect_harmony_start(int tun_fd, const char* profile_json) __attribute__((weak));
extern "C" int vpndirect_harmony_stop() __attribute__((weak));

constexpr int kCoreNotLinked = -1000;

napi_value MakeInt(napi_env env, int value) {
  napi_value result;
  napi_create_int32(env, value, &result);
  return result;
}

napi_value Start(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value argv[2] = {nullptr, nullptr};
  napi_status status = napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr);
  if (status != napi_ok || argc != 2) {
    return MakeInt(env, -22);
  }

  int32_t tun_fd = -1;
  if (napi_get_value_int32(env, argv[0], &tun_fd) != napi_ok || tun_fd < 0) {
    return MakeInt(env, -22);
  }

  size_t length = 0;
  if (napi_get_value_string_utf8(env, argv[1], nullptr, 0, &length) != napi_ok) {
    return MakeInt(env, -22);
  }

  std::string profile(length, '\0');
  if (napi_get_value_string_utf8(env, argv[1], profile.data(), length + 1, &length) != napi_ok) {
    return MakeInt(env, -22);
  }

  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_running.load()) {
    return MakeInt(env, -114);
  }

  if (vpndirect_harmony_start == nullptr) {
    return MakeInt(env, kCoreNotLinked);
  }

  const int rc = vpndirect_harmony_start(tun_fd, profile.c_str());
  if (rc == 0) {
    g_tun_fd = tun_fd;
    g_running.store(true);
  }
  return MakeInt(env, rc);
}

napi_value Stop(napi_env env, napi_callback_info info) {
  (void)info;
  std::lock_guard<std::mutex> lock(g_mutex);

  if (!g_running.load()) {
    return MakeInt(env, 0);
  }

  if (vpndirect_harmony_stop == nullptr) {
    g_tun_fd = -1;
    g_running.store(false);
    return MakeInt(env, kCoreNotLinked);
  }

  const int rc = vpndirect_harmony_stop();
  if (rc == 0) {
    g_tun_fd = -1;
    g_running.store(false);
  }
  return MakeInt(env, rc);
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
