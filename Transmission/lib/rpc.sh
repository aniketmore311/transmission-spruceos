#!/bin/sh
# Transmission RPC helpers. Sourced by launch.sh.
#
# Talks to the daemon's JSON-RPC on localhost (the same API the web UI uses).
# Credentials are read from settings.json.default (the app's committed default);
# if the web-UI password was changed the request 401s and is logged.

RPC_ENDPOINT="http://127.0.0.1:9091/transmission/rpc"
RPC_USER=""
RPC_PASS=""

RPC_TORRENT_FIELDS='["id","name","status","percentDone","rateDownload","rateUpload","peersConnected","peersSendingToUs","peersGettingFromUs","eta","totalSize","leftUntilDone","downloadedEver","uploadedEver","uploadRatio","error","errorString","trackerStats","isFinished","isStalled"]'

read_rpc_creds() {
    [ -f "$CONFIG_DEFAULT" ] || return 1
    RPC_USER="$(jq -r '.["rpc-username"] // empty' "$CONFIG_DEFAULT" 2>/dev/null)"
    RPC_PASS="$(jq -r '.["rpc-password"] // empty' "$CONFIG_DEFAULT" 2>/dev/null)"
    [ -n "$RPC_USER" ] && [ -n "$RPC_PASS" ]
}

# Write a status JSON containing only an error message, so the UI can show it.
write_status_error() {
    [ -n "${STATUS_JSON:-}" ] || return 0
    msg="$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
    printf '{"error":"%s","torrents":[],"stats":{}}' "$msg" > "$STATUS_JSON"
}

# Fetch torrent list + session stats into $STATUS_JSON.
# Returns 0 on success; on any failure $STATUS_JSON holds an "error" message.
fetch_status() {
    [ -n "${STATUS_JSON:-}" ] || return 1

    if ! daemon_is_running; then
        write_status_error "Transmission is not running"
        return 1
    fi

    if ! read_rpc_creds; then
        app_log "rpc: no credentials found in settings.json.default"
        write_status_error "No RPC credentials configured"
        return 1
    fi

    # Session-id handshake (Transmission requires it for CSRF protection).
    headers="$(curl -s -D - -o /dev/null -u "$RPC_USER:$RPC_PASS" --max-time 5 "$RPC_ENDPOINT" 2>/dev/null)"
    if [ -z "$headers" ]; then
        app_log "rpc: no response from $RPC_ENDPOINT"
        write_status_error "Cannot reach the daemon"
        return 1
    fi

    sid="$(printf '%s\n' "$headers" | awk 'tolower($1) == "x-transmission-session-id:" { print $2 }' | tr -d '\r' | head -n1)"
    code="$(printf '%s\n' "$headers" | head -n1 | awk '{ print $2 }')"

    if [ -z "$sid" ]; then
        if [ "$code" = "401" ]; then
            app_log "rpc: authentication failed (HTTP 401) for user '$RPC_USER'"
            write_status_error "Authentication failed (check settings.json.default)"
        else
            app_log "rpc: handshake failed (HTTP ${code:-unknown})"
            write_status_error "RPC handshake failed"
        fi
        return 1
    fi

    torrents="$(curl -s -u "$RPC_USER:$RPC_PASS" -H "X-Transmission-Session-Id: $sid" --max-time 8 \
        --data "{\"method\":\"torrent-get\",\"arguments\":{\"fields\":$RPC_TORRENT_FIELDS}}" \
        "$RPC_ENDPOINT" 2>/dev/null)"
    stats="$(curl -s -u "$RPC_USER:$RPC_PASS" -H "X-Transmission-Session-Id: $sid" --max-time 8 \
        --data '{"method":"session-stats"}' "$RPC_ENDPOINT" 2>/dev/null)"

    if ! printf '%s' "$torrents" | jq -e '.arguments.torrents' >/dev/null 2>&1; then
        app_log "rpc: invalid torrent-get response"
        write_status_error "Bad response from daemon"
        return 1
    fi

    [ -n "$stats" ] || stats='{}'

    if ! jq -n --argjson t "$torrents" --argjson s "$stats" \
        '{ error: "", torrents: ($t.arguments.torrents // []), stats: ($s.arguments // {}) }' \
        > "$STATUS_JSON" 2>/dev/null; then
        app_log "rpc: failed to build status JSON"
        write_status_error "Failed to parse status"
        return 1
    fi

    app_log "rpc: status fetched ($(jq '.torrents | length' "$STATUS_JSON" 2>/dev/null) torrent(s))"
    return 0
}
