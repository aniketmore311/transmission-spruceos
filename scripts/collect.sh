#!/usr/bin/env bash
# Copy the finished artifacts out of the staging dir into $OUT and write a
# manifest describing exactly what was produced.
set -euo pipefail

: "${TRANSMISSION_VERSION:?TRANSMISSION_VERSION is not set}"

OUT="${OUT:-/out}"
WORK="${WORK:-/tmp/tr-build}"
STAGE="${WORK}/stage"

mkdir -p "${OUT}"

BIN="${STAGE}/usr/bin/transmission-daemon"
if [ ! -f "${BIN}" ]; then
    BIN="$(find "${STAGE}" -type f -name transmission-daemon | head -n1)"
fi
if [ -z "${BIN}" ] || [ ! -f "${BIN}" ]; then
    echo "[collect] ERROR: transmission-daemon not found under ${STAGE}" >&2
    exit 1
fi

WEB="$(find "${STAGE}" -type d -name public_html | head -n1)"
if [ -z "${WEB}" ]; then
    echo "[collect] ERROR: web assets (public_html) not found under ${STAGE}" >&2
    exit 1
fi

cp -f "${BIN}" "${OUT}/transmission-daemon"
chmod 0755 "${OUT}/transmission-daemon"

# Drop debug info to keep the deployed binary small.
if command -v aarch64-linux-musl-strip >/dev/null 2>&1; then
    aarch64-linux-musl-strip --strip-all "${OUT}/transmission-daemon"
fi

rm -rf "${OUT}/web"
mkdir -p "${OUT}/web"
cp -a "${WEB}/." "${OUT}/web/"

SHA="$(sha256sum "${OUT}/transmission-daemon" | cut -d' ' -f1)"

cat > "${OUT}/manifest.txt" <<EOF
transmission-daemon : static aarch64 (musl) build
=================================================
transmission version : ${TRANSMISSION_VERSION}
source sha256        : ${TRANSMISSION_SHA256:-<not pinned>}
openssl version      : ${OPENSSL_VERSION:-unknown}
curl version         : ${CURL_VERSION:-unknown}
toolchain            : musl.cc aarch64-linux-musl-cross
binary sha256        : ${SHA}
build date (UTC)     : $(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

echo "[collect] artifacts written to ${OUT}:"
ls -l "${OUT}/transmission-daemon"
echo "[collect] web assets: $(find "${OUT}/web" -type f | wc -l) files"
echo
cat "${OUT}/manifest.txt"
