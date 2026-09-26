#!/usr/bin/env bash
# Install the pinned musl.cc aarch64-linux-musl cross toolchain into /opt.
set -euo pipefail

: "${MUSL_TOOLCHAIN_URL:?MUSL_TOOLCHAIN_URL is not set}"
: "${MUSL_TOOLCHAIN_SHA256:?MUSL_TOOLCHAIN_SHA256 is not set}"

DEST=/opt/aarch64-linux-musl-cross
GCC="${DEST}/bin/aarch64-linux-musl-gcc"
GXX="${DEST}/bin/aarch64-linux-musl-g++"

if [ -x "${GCC}" ] && [ -x "${GXX}" ]; then
    echo "[toolchain] already installed at ${DEST}"
else
    tmp="$(mktemp -d)"
    trap 'rm -rf "${tmp}"' EXIT
    echo "[toolchain] downloading ${MUSL_TOOLCHAIN_URL}"
    curl -fsSL -o "${tmp}/toolchain.tgz" "${MUSL_TOOLCHAIN_URL}"
    echo "${MUSL_TOOLCHAIN_SHA256}  ${tmp}/toolchain.tgz" | sha256sum -c -
    mkdir -p /opt
    tar -xzf "${tmp}/toolchain.tgz" -C /opt
fi

echo "[toolchain] gcc $( "${GCC}" -dumpversion )  g++ $( "${GXX}" -dumpversion )  installed"
