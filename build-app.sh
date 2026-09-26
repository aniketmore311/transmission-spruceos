#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Assemble the transferable SpruceOS app directory (Transmission/) from the
# daemon build artifacts in output/.
#
#   ./build-app.sh
#
# Run ./build.sh first (or whenever the daemon is rebuilt), then this script.
# It is idempotent and only copies generated files; the app's own sources
# (config.json, launch.sh, lib/, settings.json.default, README.md, icon.png) are
# authored in Transmission/ directly.
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${ROOT}/output"
APPDIR="${ROOT}/Transmission"

BIN_SRC="${OUT}/transmission-daemon"
WEB_SRC="${OUT}/web"

if [ ! -f "${BIN_SRC}" ]; then
    echo "ERROR: ${BIN_SRC} not found. Run ./build.sh first." >&2
    exit 1
fi
if [ ! -d "${WEB_SRC}" ]; then
    echo "ERROR: ${WEB_SRC} not found. Run ./build.sh first." >&2
    exit 1
fi
if [ ! -d "${APPDIR}" ]; then
    echo "ERROR: ${APPDIR} not found." >&2
    exit 1
fi

echo "[app] copying transmission-daemon"
cp -f "${BIN_SRC}" "${APPDIR}/transmission-daemon"

echo "[app] copying web/ assets"
rm -rf "${APPDIR}/web"
mkdir -p "${APPDIR}/web"
cp -a "${WEB_SRC}/." "${APPDIR}/web/"

# The app icon (Transmission/icon.png) is a committed source file, so it is
# intentionally left untouched here. Regenerate it from
# assets/transmission-icon.svg if needed.

chmod +x "${APPDIR}/transmission-daemon" \
         "${APPDIR}/launch.sh" \
         "${APPDIR}/lib/"*.sh 2>/dev/null || true
chmod +x "${APPDIR}/lib/menu_builder.py" 2>/dev/null || true

echo
echo "[app] assembled: ${APPDIR}"
ls -l "${APPDIR}"
