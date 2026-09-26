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
APP_LOG="$APP_DIR/transmission-app.log"
PID_FILE="$APP_DIR/transmission.pid"
MENU_FILE="$APP_DIR/.menu.json"
BIN="$APP_DIR/transmission-daemon"
STATUS_JSON="/tmp/transmission-status.json"

PYTHON="$(get_python_path)"
MENU_BUILDER="$APP_DIR/lib/menu_builder.py"

LOG_MAX_BYTES=1048576

. "$APP_DIR/lib/daemon.sh"
. "$APP_DIR/lib/menu.sh"
. "$APP_DIR/lib/logs.sh"
. "$APP_DIR/lib/applog.sh"
. "$APP_DIR/lib/rpc.sh"
. "$APP_DIR/lib/status.sh"

# --- one-time setup ---------------------------------------------------------
mkdir -p "$DOWNLOADS_DIR" "$INCOMPLETE_DIR" 2>/dev/null

if [ ! -f "$CONFIG_FILE" ] && [ -f "$CONFIG_DEFAULT" ]; then
    cp "$CONFIG_DEFAULT" "$CONFIG_FILE"
fi

# Seed an empty download queue so Transmission does not log a spurious
# "Couldn't read queue.json" error on a fresh install (no torrents yet).
[ -f "$APP_DIR/queue.json" ] || printf '[]' > "$APP_DIR/queue.json"

rotate_log
rotate_app_log
app_log "app launched"

cleanup() {
    kill_pyui_message_writer
    sync
}
trap cleanup EXIT INT TERM

start_pyui_message_writer 1

# --- main loop --------------------------------------------------------------
view="main"
status_id=""

while :; do
    case "$view" in
        status)        build_status_list "$MENU_FILE" ;;
        status-detail) build_status_detail "$MENU_FILE" "$status_id" ;;
        *)             build_main_menu "$MENU_FILE" ;;
    esac

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

    case "$view" in
        main)
            case "$action" in
                ACTION_START)
                    app_log "action: start transmission"
                    if daemon_start; then app_log "start: ok"; else app_log "start: FAILED"; fi
                    ;;
                ACTION_STOP)
                    app_log "action: stop transmission"
                    if daemon_stop; then app_log "stop: ok"; else app_log "stop: FAILED"; fi
                    ;;
                ACTION_STATUS)
                    app_log "open: torrent status"
                    view="status"
                    ;;
                ACTION_LOG_PATH)
                    show_log_location
                    ;;
                EXIT|"")
                    break
                    ;;
            esac
            ;;
        status)
            case "$action" in
                STATUS_REFRESH)
                    : ;; # build_status_list refetches on every redraw
                STATUS_BACK|EXIT|"")
                    view="main"
                    ;;
                TORRENT:*)
                    status_id="${action#TORRENT:}"
                    app_log "open: torrent detail id=$status_id"
                    view="status-detail"
                    ;;
            esac
            ;;
        status-detail)
            case "$action" in
                STATUS_REFRESH)
                    app_log "refresh: torrent detail id=$status_id"
                    fetch_status
                    ;;
                STATUS_BACK|EXIT|"")
                    view="status"
                    ;;
            esac
            ;;
    esac
done

app_log "app exited"
