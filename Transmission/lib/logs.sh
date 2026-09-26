#!/bin/sh
# Log housekeeping for the Transmission app. Sourced by launch.sh.

# Roll the log over once it grows past LOG_MAX_BYTES. Only done while the daemon
# is stopped, so we never rename a file the running process still holds open.
rotate_log() {
    [ -f "$LOG_FILE" ] || return 0
    daemon_is_running && return 0
    size="$(wc -c < "$LOG_FILE" 2>/dev/null | tr -d ' ')"
    [ -n "$size" ] || return 0
    if [ "$size" -gt "$LOG_MAX_BYTES" ]; then
        mv -f "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null
        : > "$LOG_FILE"
    fi
}

# Show where the log file lives. PyUI option-list labels cannot contain '/' (it
# is the sub-menu separator), so the path is shown as a message instead.
show_log_location() {
    log_and_display_message "Log file: $LOG_FILE"
    sleep 4
}
