# ---------------------------------------------------------------------------
# CMake cross toolchain: x86_64 host -> aarch64-linux-musl, fully static.
#
# Used by build-transmission.sh via -DCMAKE_TOOLCHAIN_FILE. Transmission also
# forwards this file to the bundled third-party ExternalProject builds.
# ---------------------------------------------------------------------------

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(TR_TOOLCHAIN_DIR "/opt/aarch64-linux-musl-cross" CACHE PATH "musl.cc toolchain directory")
set(TR_DEPS_PREFIX   "/opt/arm64"                  CACHE PATH "static dependency prefix")

set(CMAKE_C_COMPILER   "${TR_TOOLCHAIN_DIR}/bin/aarch64-linux-musl-gcc")
set(CMAKE_CXX_COMPILER "${TR_TOOLCHAIN_DIR}/bin/aarch64-linux-musl-g++")
set(CMAKE_AR           "${TR_TOOLCHAIN_DIR}/bin/aarch64-linux-musl-ar")
set(CMAKE_NM           "${TR_TOOLCHAIN_DIR}/bin/aarch64-linux-musl-nm")
set(CMAKE_RANLIB       "${TR_TOOLCHAIN_DIR}/bin/aarch64-linux-musl-ranlib")
set(CMAKE_STRIP        "${TR_TOOLCHAIN_DIR}/bin/aarch64-linux-musl-strip")

# Only search for headers/libraries/CMake packages inside our static prefix.
set(CMAKE_FIND_ROOT_PATH "${TR_DEPS_PREFIX}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Fully static executable.
set(CMAKE_EXE_LINKER_FLAGS_INIT "-static")

# Help find_package locate our hand-built static OpenSSL and libcurl.
set(OPENSSL_ROOT_DIR "${TR_DEPS_PREFIX}" CACHE PATH "static OpenSSL prefix")
set(CURL_INCLUDE_DIR "${TR_DEPS_PREFIX}/include"          CACHE PATH     "static libcurl headers")
set(CURL_LIBRARY     "${TR_DEPS_PREFIX}/lib/libcurl.a"    CACHE FILEPATH "static libcurl archive")
