cmake_minimum_required(VERSION 3.5.0)
project(vpndirect_harmony)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_library(vpndirect_core SHARED
    napi_init.cpp
)

target_include_directories(vpndirect_core PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
)

# The actual VPN Direct Core library is intentionally supplied by the
# HarmonyOS Core build. Do not substitute an Android .so or a stock sing-box
# binary here. The final integration will link the pinned ARM64
# libvpndirect_core.so after the Core build is implemented.
