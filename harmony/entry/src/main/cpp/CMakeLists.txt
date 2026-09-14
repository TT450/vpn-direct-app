cmake_minimum_required(VERSION 3.5.0)
project(vpndirect_harmony)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# The engine is deliberately a separate shared object. The N-API bridge loads
# it by soname at runtime, so the HAP must package both libraries together.
# A missing engine is a build error: shipping the bridge without the engine
# would produce an apparently installable but non-functional VPN client.
set(VPN_ENGINE_SO "${CMAKE_CURRENT_SOURCE_DIR}/prebuilt/arm64-v8a/libvpndirect_engine.so")
if(NOT EXISTS "${VPN_ENGINE_SO}")
    message(FATAL_ERROR
        "Missing ${VPN_ENGINE_SO}. Run scripts/build_harmony_core.sh on a HarmonyOS/arm64 build host before building the HAP.")
endif()

add_library(vpndirect_engine SHARED IMPORTED GLOBAL)
set_target_properties(vpndirect_engine PROPERTIES
    IMPORTED_LOCATION "${VPN_ENGINE_SO}"
)

add_library(vpndirect_core SHARED
    napi_init.cpp
)

target_include_directories(vpndirect_core PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

target_link_libraries(vpndirect_core PUBLIC
    vpndirect_engine
)
