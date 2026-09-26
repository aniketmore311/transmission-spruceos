#!/bin/sh
# App-level logging for the Transmission app. Sourced by launch.sh.
#
# Writes to the app's own log (transmission-app.log), separate from the daemon
# log. Uses the SpruceOS log_message helper with a custom destination file.

app_log() {
    [ -n "${APP_LOG:-}" ] || return 0
    log_message "$1" "" "$APP_LOG"
}

# Show a short confirmation/error message on screen and record it in the log.
# MESSAGE cannot wait for a button, so it is shown for a fixed short time.
app_toast() {
    app_log "toast: $1"
    log_and_display_message "$1"
    sleep 1.5
}

# Rotate the app log once it grows past LOG_MAX_BYTES. Unlike the daemon log we
# own this file, so it can be rotated at any time.
rotate_app_log() {
    [ -n "${APP_LOG:-}" ] || return 0
    [ -f "$APP_LOG" ] || return 0
    size="$(wc -c < "$APP_LOG" 2>/dev/null | tr -d ' ')"
    [ -n "$size" ] || return 0
    if [ "$size" -gt "$LOG_MAX_BYTES" ]; then
        mv -f "$APP_LOG" "$APP_LOG.1" 2>/dev/null
        : > "$APP_LOG"
    fi
}
