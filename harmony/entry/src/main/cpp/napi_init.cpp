#include <napi/native_api.h>

#include <atomic>
#include <dlfcn.h>
#include <mutex>
#include <string>

namespace {
std::mutex g_mutex;
std::atomic<bool> g_running{false};
void* g_core_handle = nullptr;

using CoreStartFn = int (*)(int, const char*);
using CoreStopFn = int (*)();
CoreStartFn g_core_start = nullptr;
CoreStopFn g_core_stop = nullptr;

constexpr int kCoreNotLinked = -1000;
constexpr const char* kCoreLibrary = "libvpndirect_engine.so";

napi_value MakeInt(napi_env env, int value) {
  napi_value result;
  napi_create_int32(env, value, &result);
  return result;
}

bool LoadCore() {
  if (g_core_handle != nullptr && g_core_start != nullptr && g_core_stop != nullptr) return true;

  g_core_handle = dlopen(kCoreLibrary, RTLD_NOW | RTLD_LOCAL);
  if (g_core_handle == nullptr) return false;

  g_core_start = reinterpret_cast<CoreStartFn>(dlsym(g_core_handle, "vpndirect_harmony_start"));
  g_core_stop = reinterpret_cast<CoreStopFn>(dlsym(g_core_handle, "vpndirect_harmony_stop"));
  if (g_core_start == nullptr || g_core_stop == nullptr) {
    dlclose(g_core_handle);
    g_core_handle = nullptr;
    g_core_start = nullptr;
    g_core_stop = nullptr;
    return false;
  }
  return true;
}

napi_value Start(napi_env env, napi_callback_info info) {
  size_t argc = 2;
  napi_value argv[2] = {nullptr, nullptr};
  if (napi_get_cb_info(env, info, &argc, argv, nullptr, nullptr) != napi_ok || argc != 2) {
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
  if (g_running.load()) return MakeInt(env, -114);
  if (!LoadCore()) return MakeInt(env, kCoreNotLinked);

  const int rc = g_core_start(tun_fd, profile.c_str());
  if (rc == 0) g_running.store(true);
  return MakeInt(env, rc);
}

napi_value Stop(napi_env env, napi_callback_info info) {
  (void)info;
  std::lock_guard<std::mutex> lock(g_mutex);
  if (!g_running.load()) return MakeInt(env, 0);
  if (g_core_stop == nullptr) return MakeInt(env, kCoreNotLinked);

  const int rc = g_core_stop();
  if (rc == 0) g_running.store(false);
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
