#!/bin/sh
# Transmission - SpruceOS app entry point.
#
# Starts/stops the bundled static transmission-daemon and renders a controller
# friendly menu using the shared PyUI realtime message interface. Everything the
# app owns lives in this directory; the only external path is the download folder
# on the SD card (/mnt/SDCARD/Roms/MEDIA + .incomplete), created here if missing.

. /mnt/SDCARD/spruce/scripts/helperFunctions.sh

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
DOWNLOADS_DIR="/mnt/SDCARD/Roms/MEDIA"
INCOMPLETE_DIR="/mnt/SDCARD/Roms/MEDIA/.incomplete"
SELECTION_FILE="/mnt/SDCARD/App/PyUI/selection.txt"

CONFIG_FILE="$APP_DIR/settings.json"
CONFIG_DEFAULT="$APP_DIR/settings.json.default"
LOG_FILE="$APP_DIR/transmission.log"
PID_FILE="$APP_DIR/transmission.pid"
MENU_FILE="$APP_DIR/.menu.json"
BIN="$APP_DIR/transmission-daemon"

PYTHON="$(get_python_path)"
MENU_BUILDER="$APP_DIR/lib/menu_builder.py"

LOG_MAX_BYTES=1048576

. "$APP_DIR/lib/daemon.sh"
. "$APP_DIR/lib/menu.sh"
. "$APP_DIR/lib/logs.sh"

# --- one-time setup ---------------------------------------------------------
mkdir -p "$DOWNLOADS_DIR" "$INCOMPLETE_DIR" 2>/dev/null

if [ ! -f "$CONFIG_FILE" ] && [ -f "$CONFIG_DEFAULT" ]; then
    cp "$CONFIG_DEFAULT" "$CONFIG_FILE"
fi

# Seed an empty download queue so Transmission does not log a spurious
# "Couldn't read queue.json" error on a fresh install (no torrents yet).
[ -f "$APP_DIR/queue.json" ] || printf '[]' > "$APP_DIR/queue.json"

rotate_log

cleanup() {
    kill_pyui_message_writer
    sync
}
trap cleanup EXIT INT TERM

start_pyui_message_writer 1

# --- main loop --------------------------------------------------------------
while :; do
    build_main_menu "$MENU_FILE"

    rm -f "$SELECTION_FILE"
    display_option_list "$MENU_FILE"

    # Wait for the user to pick something. Bail out if the UI process goes away.
    while [ ! -f "$SELECTION_FILE" ]; do
        sleep 0.2
        if ! pgrep -f "sgDisplayRealtimePort" >/dev/null 2>&1; then
            break
        fi
    done

    if [ ! -f "$SELECTION_FILE" ]; then
        break
    fi
    action="$(cat "$SELECTION_FILE" 2>/dev/null)"
    rm -f "$SELECTION_FILE"

    case "$action" in
        ACTION_START)    daemon_start ;;
        ACTION_STOP)     daemon_stop ;;
        ACTION_LOG_PATH) show_log_location ;;
        EXIT|"")         break ;;
        *)               : ;;
    esac
done
