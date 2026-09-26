#!/bin/sh
# transmission-daemon lifecycle helpers. Sourced by launch.sh; relies on the
# variables APP_DIR, PID_FILE, LOG_FILE and BIN being defined there.

daemon_pid() {
    [ -f "$PID_FILE" ] || return 1
    pid="$(tr -d ' \r\n' < "$PID_FILE" 2>/dev/null)"
    [ -n "$pid" ] || return 1
    kill -0 "$pid" 2>/dev/null || return 1
    printf '%s' "$pid"
    return 0
}

daemon_is_running() {
    daemon_pid >/dev/null 2>&1
}

daemon_status_text() {
    if pid="$(daemon_pid)"; then
        printf 'Status: Running (PID %s)' "$pid"
    else
        printf 'Status: Stopped'
    fi
}

daemon_start() {
    if daemon_is_running; then
        log_message "Transmission is already running."
        return 0
    fi

    rm -f "$PID_FILE"
    export TRANSMISSION_WEB_HOME="$APP_DIR/web"
    export HOME="$APP_DIR"

    log_message "Starting transmission-daemon..."
    "$BIN" \
        --config-dir "$APP_DIR" \
        --logfile "$LOG_FILE" \
        --log-level=info \
        --pid-file "$PID_FILE" >/dev/null 2>&1
    rc=$?

    i=0
    while [ "$i" -lt 20 ]; do
        daemon_is_running && break
        sleep 0.25
        i=$((i + 1))
    done
    sync

    if daemon_is_running; then
        log_message "Transmission started (PID $(daemon_pid))."
        return 0
    fi
    log_message "Transmission failed to start (exit $rc)."
    return 1
}

daemon_stop() {
    pid="$(daemon_pid)"
    if [ -z "$pid" ]; then
        # No valid pidfile: clean up any stray process just in case.
        if pgrep -f 'transmission-daemon' >/dev/null 2>&1; then
            killall transmission-daemon 2>/dev/null
            sleep 1
            killall -9 transmission-daemon 2>/dev/null
        fi
        rm -f "$PID_FILE"
        return 0
    fi

    log_message "Stopping transmission-daemon (PID $pid)..."
    kill "$pid" 2>/dev/null

    i=0
    while [ "$i" -lt 40 ]; do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.25
        i=$((i + 1))
    done

    if kill -0 "$pid" 2>/dev/null; then
        log_message "Force killing transmission-daemon (PID $pid)."
        kill -9 "$pid" 2>/dev/null
        sleep 0.5
    fi

    rm -f "$PID_FILE"
    sync
    return 0
}
