#!/bin/sh
# Web UI helpers. Sourced by launch.sh.

device_ip() {
    ip="$(ip -4 addr show wlan0 2>/dev/null | awk '/inet /{ sub("/.*", "", $2); print $2; exit }')"
    if [ -z "$ip" ]; then
        ip="$(ifconfig wlan0 2>/dev/null | awk '/inet addr/{ split($2, a, ":"); print a[2]; exit }')"
    fi
    printf '%s' "$ip"
}

# Show the web UI URL as a QR code. Rendered full-screen (not beside a menu).
show_webui_qr() {
    ip="$(device_ip)"
    if [ -z "$ip" ]; then
        app_toast "No Wi-Fi address found"
        return 1
    fi

    url="http://$ip:9091/transmission/web/"
    qr="$APP_DIR/.qr.png"
    rm -f "$qr"

    if ! qrencode -o "$qr" -s 3 -l M -m 2 "$url" >/dev/null 2>&1; then
        app_log "webui: qr generation failed"
        app_toast "Could not generate QR code"
        return 1
    fi

    app_log "webui: showing QR for $url"
    display_image_and_text "$qr" 60 10 "$url" 86
    sleep 8
    rm -f "$qr"
}
