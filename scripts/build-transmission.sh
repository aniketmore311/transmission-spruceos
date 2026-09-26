#!/usr/bin/env bash
# Download, verify, cross-compile and install the requested Transmission release
# as a fully static aarch64 (musl) transmission-daemon. Runs inside the Docker
# builder image. Artifacts are written to $OUT by collect.sh.
set -euo pipefail

: "${TRANSMISSION_VERSION:?TRANSMISSION_VERSION is not set}"

OUT="${OUT:-/out}"
WORK="${WORK:-/tmp/tr-build}"
PREFIX=/opt/arm64
JOBS="${JOBS:-$(nproc)}"

export PATH="/opt/aarch64-linux-musl-cross/bin:${PATH}"
export PKG_CONFIG_PATH="${PREFIX}/lib/pkgconfig"
export PKG_CONFIG_LIBDIR="${PREFIX}/lib/pkgconfig"

rm -rf "${WORK}"
mkdir -p "${WORK}"
cd "${WORK}"

TARBALL="transmission-${TRANSMISSION_VERSION}.tar.xz"
URL="https://github.com/transmission/transmission/releases/download/${TRANSMISSION_VERSION}/${TARBALL}"

echo "[transmission] downloading ${URL}"
curl -fsSL -o "${TARBALL}" "${URL}"

if [ -n "${TRANSMISSION_SHA256:-}" ]; then
    echo "${TRANSMISSION_SHA256}  ${TARBALL}" | sha256sum -c -
fi

tar xf "${TARBALL}"
SRC="${WORK}/transmission-${TRANSMISSION_VERSION}"

echo "[transmission] configuring..."
cmake -S "${SRC}" -B "${WORK}/build" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE=/cmake/aarch64-linux-musl.cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCMAKE_EXE_LINKER_FLAGS="-static" \
    -DCMAKE_CXX_STANDARD_LIBRARIES="-L${PREFIX}/lib -lssl -lcrypto" \
    -DCMAKE_C_STANDARD_LIBRARIES="-L${PREFIX}/lib -lssl -lcrypto" \
    -DENABLE_DAEMON=ON \
    -DENABLE_CLI=OFF \
    -DENABLE_UTILS=OFF \
    -DENABLE_QT=OFF \
    -DENABLE_GTK=OFF \
    -DENABLE_TESTS=OFF \
    -DENABLE_NLS=OFF \
    -DINSTALL_WEB=ON \
    -DINSTALL_DOC=OFF \
    -DWITH_CRYPTO=openssl \
    -DUSE_SYSTEM_EVENT2=OFF \
    -DUSE_SYSTEM_DEFLATE=OFF \
    -DUSE_SYSTEM_DHT=OFF \
    -DUSE_SYSTEM_UTP=OFF \
    -DUSE_SYSTEM_B64=OFF \
    -DUSE_SYSTEM_PSL=OFF \
    -DUSE_SYSTEM_NATPMP=OFF \
    -DUSE_SYSTEM_MINIUPNPC=OFF \
    -DWITH_INOTIFY=OFF \
    -DWITH_KQUEUE=OFF \
    -DWITH_SYSTEMD=OFF

echo "[transmission] building with ${JOBS} job(s)..."
cmake --build "${WORK}/build" -j"${JOBS}"

echo "[transmission] installing to staging dir..."
DESTDIR="${WORK}/stage" cmake --install "${WORK}/build"

/scripts/collect.sh
