#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# One-command rebuild of a fully static aarch64 transmission-daemon.
#
#   ./build.sh                     build the latest official stable release
#   ./build.sh --version 4.1.3     build a specific release
#   ./build.sh --no-cache          rebuild the Docker builder image from scratch
#   ./build.sh --jobs 4            limit parallel build jobs
#
# Artifacts land in ./output/ (binary + web/ + manifest.txt).
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${ROOT}"

# shellcheck disable=SC1091
source ./versions.env

BUILDER_IMAGE="transmission-aarch64-builder:${OPENSSL_VERSION}-${CURL_VERSION}"
TRANSMISSION_VERSION_ARG=""
NO_CACHE=""
JOBS="$(nproc)"

usage() {
    cat <<EOF
Usage: ./build.sh [options]

Options:
  -v, --version X.Y.Z   Build a specific Transmission release (default: latest stable)
      --no-cache        Rebuild the Docker builder image from scratch
  -j, --jobs N          Parallel build jobs (default: $(nproc))
  -h, --help            Show this help

Artifacts are written to ./output/
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        -v|--version) TRANSMISSION_VERSION_ARG="$2"; shift 2 ;;
        --no-cache)   NO_CACHE="--no-cache"; shift ;;
        -j|--jobs)    JOBS="$2"; shift 2 ;;
        -h|--help)    usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required but not found." >&2; exit 1; }

# --- Resolve version --------------------------------------------------------
if [ -n "${TRANSMISSION_VERSION_ARG}" ]; then
    VERSION="${TRANSMISSION_VERSION_ARG}"
else
    echo "[build] resolving latest stable Transmission release..."
    VERSION="$(curl -fsSL https://api.github.com/repos/transmission/transmission/releases/latest \
        | python3 -c "import json,sys; print(json.load(sys.stdin)['tag_name'])")"
fi
echo "[build] Transmission version: ${VERSION}"

# --- Resolve expected source checksum --------------------------------------
SOURCE_SHA=""
if [ "${VERSION}" = "${TRANSMISSION_VERSION}" ] && [ -n "${TRANSMISSION_SHA256}" ]; then
    SOURCE_SHA="${TRANSMISSION_SHA256}"
else
    SOURCE_SHA="$(curl -fsSL "https://api.github.com/repos/transmission/transmission/releases/tags/${VERSION}" \
        | python3 -c "
import json, sys
d = json.load(sys.stdin)
name = 'transmission-${VERSION}.tar.xz'
for a in d.get('assets', []):
    if a.get('name') == name:
        print((a.get('digest') or '').replace('sha256:', ''))
        break
" || true)"
fi
if [ -z "${SOURCE_SHA}" ]; then
    echo "[build] WARNING: no source checksum available; the tarball will not be verified." >&2
else
    echo "[build] source sha256: ${SOURCE_SHA}"
fi

# --- Build the Docker builder image ----------------------------------------
echo "[build] building Docker builder image ${BUILDER_IMAGE} ..."
docker build ${NO_CACHE} -t "${BUILDER_IMAGE}" \
    --build-arg MUSL_TOOLCHAIN_URL="${MUSL_TOOLCHAIN_URL}" \
    --build-arg MUSL_TOOLCHAIN_SHA256="${MUSL_TOOLCHAIN_SHA256}" \
    --build-arg OPENSSL_VERSION="${OPENSSL_VERSION}" \
    --build-arg OPENSSL_SHA256="${OPENSSL_SHA256}" \
    --build-arg CURL_VERSION="${CURL_VERSION}" \
    --build-arg CURL_SHA256="${CURL_SHA256}" \
    -f Dockerfile .

# --- Compile Transmission ---------------------------------------------------
mkdir -p "${ROOT}/output"
echo "[build] compiling transmission-${VERSION} ..."
docker run --rm \
    -e TRANSMISSION_VERSION="${VERSION}" \
    -e TRANSMISSION_SHA256="${SOURCE_SHA}" \
    -e JOBS="${JOBS}" \
    -v "${ROOT}/output:/out" \
    "${BUILDER_IMAGE}"

echo
echo "[build] done. artifacts in ${ROOT}/output:"
ls -l "${ROOT}/output"
