#!/bin/sh
# Torrent status views. Sourced by launch.sh.

# List view always fetches fresh data (so entering the screen and pressing
# Refresh both show current stats).
build_status_list() {
    out="$1"
    fetch_status
    "$PYTHON" "$MENU_BUILDER" status-list "$out" "$STATUS_JSON"
}

# Detail view renders from the already-fetched status JSON; the caller refreshes
# it explicitly when the user picks Refresh.
build_status_detail() {
    out="$1"
    "$PYTHON" "$MENU_BUILDER" status-detail "$out" "$STATUS_JSON" "$2"
}
