#!/bin/sh
# Main-menu construction for the Transmission app. Sourced by launch.sh.

build_main_menu() {
    out="$1"
    status="$(daemon_status_text)"
    if daemon_is_running; then
        action_label="Stop Transmission"
        action_token="ACTION_STOP"
        # Quiet fetch so the summary/label are current; errors are still logged.
        fetch_status quiet
        "$PYTHON" "$MENU_BUILDER" main "$out" "$status" "$action_label" "$action_token" "$STATUS_JSON"
    else
        action_label="Start Transmission"
        action_token="ACTION_START"
        "$PYTHON" "$MENU_BUILDER" main "$out" "$status" "$action_label" "$action_token"
    fi
}
