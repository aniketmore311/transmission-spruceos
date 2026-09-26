#!/bin/sh
# Main-menu construction for the Transmission app. Sourced by launch.sh.

build_main_menu() {
    out="$1"
    status="$(daemon_status_text)"
    if daemon_is_running; then
        action_label="Stop Transmission"
        action_token="ACTION_STOP"
    else
        action_label="Start Transmission"
        action_token="ACTION_START"
    fi
    "$PYTHON" "$MENU_BUILDER" main "$out" "$status" "$action_label" "$action_token"
}
