#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Assemble the transferable SpruceOS app directory (Transmission/) from the
# daemon build artifacts in output/.
#
#   ./build-app.sh
#
# Run ./build.sh first (or whenever the daemon is rebuilt), then this script.
# It is idempotent and only copies generated files; the app's own sources
# (config.json, launch.sh, lib/, settings.json.default, README.md) are authored
# in Transmission/ directly.
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="${ROOT}/output"
APPDIR="${ROOT}/Transmission"

BIN_SRC="${OUT}/transmission-daemon"
WEB_SRC="${OUT}/web"
ICON_SRC="${OUT}/web/images/apple-touch-icon.png"

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

# Placeholder icon for now (reuses the official web touch icon).
if [ -f "${ICON_SRC}" ]; then
    echo "[app] placing placeholder icon.png"
    cp -f "${ICON_SRC}" "${APPDIR}/icon.png"
fi

chmod +x "${APPDIR}/transmission-daemon" \
         "${APPDIR}/launch.sh" \
         "${APPDIR}/lib/"*.sh 2>/dev/null || true
chmod +x "${APPDIR}/lib/menu_builder.py" 2>/dev/null || true

echo
echo "[app] assembled: ${APPDIR}"
ls -l "${APPDIR}"
