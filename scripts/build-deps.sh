#!/usr/bin/env bash
# Build the only two external dependencies Transmission 4.x truly requires:
#   * OpenSSL  (crypto / TLS)
#   * libcurl  (find_package(CURL) is REQUIRED)
# Both are linked statically into the daemon. Everything else (libevent,
# libdeflate, dht, libutp, libb64, libpsl, libnatpmp, miniupnpc, ...) is
# bundled in the Transmission source tree.
set -euo pipefail

export PREFIX=/opt/arm64
export PATH="/opt/aarch64-linux-musl-cross/bin:${PATH}"
export CC=aarch64-linux-musl-gcc
export CXX=aarch64-linux-musl-g++
export AR=aarch64-linux-musl-ar
export RANLIB=aarch64-linux-musl-ranlib
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="${PREFIX}/lib/pkgconfig"

: "${OPENSSL_VERSION:?OPENSSL_VERSION is not set}"
: "${OPENSSL_SHA256:?OPENSSL_SHA256 is not set}"
: "${CURL_VERSION:?CURL_VERSION is not set}"
: "${CURL_SHA256:?CURL_SHA256 is not set}"

JOBS="$(nproc)"
mkdir -p "${PREFIX}" /tmp/deps
cd /tmp/deps

# --------------------------------------------------------------------------
# OpenSSL (static). Built in a subshell so its unset CC/CXX do not leak out.
# --------------------------------------------------------------------------
if [ ! -f "${PREFIX}/lib/libssl.a" ]; then
    (
        set -euo pipefail
        curl -fsSL -o openssl.tar.gz \
            "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz"
        echo "${OPENSSL_SHA256}  openssl.tar.gz" | sha256sum -c -
        tar xf openssl.tar.gz
        cd "openssl-${OPENSSL_VERSION}"
        # Let --cross-compile-prefix drive the tool selection for OpenSSL.
        unset CC CXX AR RANLIB CFLAGS LDFLAGS
        ./Configure linux-aarch64 \
            --cross-compile-prefix=aarch64-linux-musl- \
            --prefix="${PREFIX}" \
            --openssldir="${PREFIX}/ssl" \
            no-shared no-tests no-async
        make -j"${JOBS}" build_sw
        make install_sw
    )
fi

# --------------------------------------------------------------------------
# libcurl (static, OpenSSL backend, no zlib/psl to keep it small).
# --------------------------------------------------------------------------
if [ ! -f "${PREFIX}/lib/libcurl.a" ]; then
    (
        set -euo pipefail
        curl -fsSL -o curl.tar.gz \
            "https://curl.se/download/curl-${CURL_VERSION}.tar.gz"
        echo "${CURL_SHA256}  curl.tar.gz" | sha256sum -c -
        tar xf curl.tar.gz
        cd "curl-${CURL_VERSION}"
        ./configure \
            --host=aarch64-linux-musl \
            --prefix="${PREFIX}" \
            --disable-shared --enable-static \
            --with-openssl="${PREFIX}" \
            --without-zlib --without-libpsl --without-brotli --without-zstd \
            --without-libidn2 --without-librtmp --without-nghttp2 \
            --disable-ldap --disable-ldaps --disable-rtsp --disable-dict \
            --disable-telnet --disable-tftp --disable-pop3 --disable-imap \
            --disable-smtp --disable-gopher --disable-mqtt --disable-manual \
            --disable-docs --enable-protocol=http,https,file \
            CFLAGS="-O2"
        make -j"${JOBS}"
        make install
    )
fi

echo "[deps] static libraries installed in ${PREFIX}/lib:"
ls -1 "${PREFIX}/lib"/*.a
