#!/bin/sh
# Transmission RPC helpers. Sourced by launch.sh.
#
# Talks to the daemon's JSON-RPC on localhost (the same API the web UI uses).
# Credentials are read from settings.json.default (the app's committed default);
# if the web-UI password was changed the request 401s and is logged.

RPC_ENDPOINT="http://127.0.0.1:9091/transmission/rpc"
RPC_RESP="/tmp/transmission-rpc.json"
RPC_USER=""
RPC_PASS=""
RPC_ERR=""

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

# Low-level RPC call. Response is written to $RPC_RESP; on failure RPC_ERR holds
# a human-readable reason and the function returns non-zero.
rpc_simple() {
    body="$1"
    RPC_ERR=""
    : > "$RPC_RESP"

    if ! read_rpc_creds; then
        RPC_ERR="No RPC credentials configured"
        return 1
    fi

    headers="$(curl -s -D - -o /dev/null -u "$RPC_USER:$RPC_PASS" --max-time 5 "$RPC_ENDPOINT" 2>/dev/null)"
    if [ -z "$headers" ]; then
        RPC_ERR="Cannot reach the daemon"
        return 1
    fi

    sid="$(printf '%s\n' "$headers" | awk 'tolower($1) == "x-transmission-session-id:" { print $2 }' | tr -d '\r' | head -n1)"
    if [ -z "$sid" ]; then
        code="$(printf '%s\n' "$headers" | head -n1 | awk '{ print $2 }')"
        if [ "$code" = "401" ]; then
            RPC_ERR="Authentication failed (check settings.json.default)"
        else
            RPC_ERR="RPC handshake failed"
        fi
        return 1
    fi

    curl -s -u "$RPC_USER:$RPC_PASS" -H "X-Transmission-Session-Id: $sid" --max-time 8 \
        --data "$body" -o "$RPC_RESP" "$RPC_ENDPOINT" 2>/dev/null
    return 0
}

# Fetch torrent list + session stats into $STATUS_JSON.
# Pass "quiet" to suppress the success log line (used by the main-menu summary).
fetch_status() {
    quiet="${1:-}"
    [ -n "${STATUS_JSON:-}" ] || return 1

    if ! daemon_is_running; then
        write_status_error "Transmission is not running"
        return 1
    fi

    if ! rpc_simple "{\"method\":\"torrent-get\",\"arguments\":{\"fields\":$RPC_TORRENT_FIELDS}}"; then
        app_log "rpc: torrent-get failed: ${RPC_ERR:-unknown}"
        write_status_error "$RPC_ERR"
        return 1
    fi

    torrents="$(cat "$RPC_RESP")"
    if ! printf '%s' "$torrents" | jq -e '.arguments.torrents' >/dev/null 2>&1; then
        app_log "rpc: invalid torrent-get response"
        write_status_error "Bad response from daemon"
        return 1
    fi

    if rpc_simple '{"method":"session-stats"}'; then
        stats="$(cat "$RPC_RESP")"
    else
        stats='{}'
    fi

    if ! jq -n --argjson t "$torrents" --argjson s "$stats" \
        '{ error: "", torrents: ($t.arguments.torrents // []), stats: ($s.arguments // {}) }' \
        > "$STATUS_JSON" 2>/dev/null; then
        app_log "rpc: failed to build status JSON"
        write_status_error "Failed to parse status"
        return 1
    fi

    if [ "$quiet" != "quiet" ]; then
        app_log "rpc: status fetched ($(jq '.torrents | length' "$STATUS_JSON" 2>/dev/null) torrent(s))"
    fi
    return 0
}

# Perform a per-torrent action. $1 = method, $2 = id, $3 = optional extra args.
torrent_action() {
    method="$1"
    tid="$2"
    extra="$3"

    if [ -n "$extra" ]; then
        body="{\"method\":\"$method\",\"arguments\":{\"ids\":[$tid],$extra}}"
    else
        body="{\"method\":\"$method\",\"arguments\":{\"ids\":[$tid]}}"
    fi

    if rpc_simple "$body" && jq -e '.result == "success"' "$RPC_RESP" >/dev/null 2>&1; then
        app_log "rpc: $method id=$tid ok"
        return 0
    fi
    app_log "rpc: $method id=$tid FAILED: ${RPC_ERR:-unknown}"
    return 1
}
