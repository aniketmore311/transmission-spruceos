#!/bin/sh
# Torrent status views and actions. Sourced by launch.sh.

# Name of the torrent with the given id (from the current status JSON).
torrent_name() {
    jq -r --arg id "$1" '.torrents[] | select((.id | tostring) == $id) | .name' "$STATUS_JSON" 2>/dev/null | head -n1
}

# List view always fetches fresh data (so entering the screen and pressing
# Refresh both show current stats).
build_status_list() {
    out="$1"
    filter="$2"
    fetch_status
    "$PYTHON" "$MENU_BUILDER" status-list "$out" "$STATUS_JSON" "$filter"
}

# Detail view renders from the already-fetched status JSON; the caller refreshes
# it explicitly when the user picks Refresh or runs an action.
build_status_detail() {
    out="$1"
    "$PYTHON" "$MENU_BUILDER" status-detail "$out" "$STATUS_JSON" "$2"
}

build_status_remove() {
    out="$1"
    name="$(torrent_name "$2")"
    "$PYTHON" "$MENU_BUILDER" status-remove "$out" "$name"
}
