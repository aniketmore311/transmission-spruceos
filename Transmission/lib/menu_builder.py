#!/usr/bin/env python3
"""Build PyUI OPTION_LIST menu JSON for the Transmission app.

Usage:
    menu_builder.py main <out.json> <status> <action_label> <action_token>
    menu_builder.py status-list <out.json> <status.json>
    menu_builder.py status-detail <out.json> <status.json> <torrent_id>

PyUI treats '/' in an option label as a sub-menu separator, so every label is
sanitised by replacing '/' with '|'.
"""
import json
import sys

_STATUS_NAMES = {
    0: "stopped",
    1: "queued (verify)",
    2: "checking",
    3: "queued (download)",
    4: "downloading",
    5: "queued (seed)",
    6: "seeding",
}


# ----------------------------------------------------------------- helpers

def _sanitize(text):
    return str(text).replace("/", "|")


def _fmt_size(num):
    try:
        n = float(num or 0)
    except (TypeError, ValueError):
        n = 0.0
    for unit in ("B", "kB", "MB", "GB", "TB"):
        if n < 1000.0 or unit == "TB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1000.0


def _fmt_rate(num):
    return _fmt_size(num) + "/s"


def _fmt_eta(eta):
    try:
        eta = int(eta)
    except (TypeError, ValueError):
        return "-"
    if eta < 0:
        return "-"
    if eta < 60:
        return f"{eta}s"
    if eta < 3600:
        return f"{eta // 60}m {eta % 60:02d}s"
    return f"{eta // 3600}h {(eta % 3600) // 60:02d}m"


def _short(name, maxlen=34):
    text = _sanitize(name)
    if len(text) > maxlen:
        text = text[: maxlen - 1] + "…"
    return text
    return text


def _tracker_totals(torrent):
    seeders = leechers = 0
    for stat in torrent.get("trackerStats") or []:
        val = stat.get("seederCount")
        if isinstance(val, int) and val > 0:
            seeders += val
        val = stat.get("leecherCount")
        if isinstance(val, int) and val > 0:
            leechers += val
    return seeders, leechers


def _write(path, menu):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(menu, handle, ensure_ascii=False)


def _load(path):
    with open(path, "r", encoding="utf-8") as handle:
        return json.load(handle)


# ---------------------------------------------------------------- builders

def build_main(path, status, action_label, action_token):
    status = _sanitize(status)
    action_label = _sanitize(action_label)
    menu = {
        status: "ACTION_NONE",
        action_label: action_token,
        "Torrent status": "ACTION_STATUS",
        "Log file location": "ACTION_LOG_PATH",
    }
    _write(path, menu)


def build_status_list(path, status):
    torrents = status.get("torrents") or []
    stats = status.get("stats") or {}
    error = status.get("error") or ""

    menu = {}
    if error:
        menu["Status unavailable: " + _sanitize(error)] = "ACTION_NONE"
    elif not torrents:
        menu["No torrents"] = "ACTION_NONE"
    else:
        active = sum(1 for t in torrents if t.get("status") not in (0,))
        summary = (
            f"↓ {_fmt_rate(stats.get('downloadSpeed'))}   "
            f"↑ {_fmt_rate(stats.get('uploadSpeed'))}   "
            f"·   {active} active of {len(torrents)}"
        )
        menu[summary] = "ACTION_NONE"
        for index, torrent in enumerate(torrents):
            state = torrent.get("status", 0)
            pct = torrent.get("percentDone", 0) * 100
            label = f"{index + 1:02d}  {_short(torrent.get('name', '?'))}  ·  {pct:.1f}%"
            if state == 4:
                label += f"  ·  ↓{_fmt_rate(torrent.get('rateDownload'))}"
            elif state == 6:
                label += f"  ·  ↑{_fmt_rate(torrent.get('rateUpload'))}"
            else:
                label += f"  ·  {_STATUS_NAMES.get(state, '?')}"
            menu[label] = f"TORRENT:{torrent.get('id')}"

    menu["Refresh"] = "STATUS_REFRESH"
    menu["Back to Menu"] = "STATUS_BACK"
    _write(path, menu)


def build_status_detail(path, status, torrent_id):
    torrent = None
    for item in status.get("torrents") or []:
        if str(item.get("id")) == str(torrent_id):
            torrent = item
            break

    menu = {}
    if torrent is None:
        menu["Torrent not found"] = "ACTION_NONE"
    else:
        seeders, leechers = _tracker_totals(torrent)
        menu[f"Name: {_short(torrent.get('name', '?'), 60)}"] = "ACTION_NONE"
        menu[f"State: {_STATUS_NAMES.get(torrent.get('status', 0), '?')}"] = "ACTION_NONE"
        menu[f"Progress: {torrent.get('percentDone', 0) * 100:.1f}%"] = "ACTION_NONE"
        menu[f"Size: {_fmt_size(torrent.get('totalSize'))}   Remaining: {_fmt_size(torrent.get('leftUntilDone'))}"] = "ACTION_NONE"
        menu[f"Down: {_fmt_rate(torrent.get('rateDownload'))}   Up: {_fmt_rate(torrent.get('rateUpload'))}"] = "ACTION_NONE"
        menu[f"Peers: {torrent.get('peersConnected', 0)} (in {torrent.get('peersGettingFromUs', 0)}, out {torrent.get('peersSendingToUs', 0)})"] = "ACTION_NONE"
        menu[f"Trackers: {seeders} seeders, {leechers} leechers"] = "ACTION_NONE"
        menu[f"Ratio: {float(torrent.get('uploadRatio', 0) or 0):.2f}   Downloaded: {_fmt_size(torrent.get('downloadedEver'))}"] = "ACTION_NONE"
        menu[f"ETA: {_fmt_eta(torrent.get('eta'))}"] = "ACTION_NONE"
        err = torrent.get("errorString") or ""
        if err:
            menu["Error: " + _sanitize(err)] = "ACTION_NONE"

    menu["Refresh"] = "STATUS_REFRESH"
    menu["Back to List"] = "STATUS_BACK"
    _write(path, menu)


def main():
    args = sys.argv[1:]
    if not args:
        sys.exit("usage: menu_builder.py <mode> ...")
    mode = args[0]
    if mode == "main":
        build_main(args[1], args[2], args[3], args[4])
    elif mode == "status-list":
        build_status_list(args[1], _load(args[2]))
    elif mode == "status-detail":
        build_status_detail(args[1], _load(args[2]), args[3])
    else:
        sys.exit("unknown mode: %s" % mode)


if __name__ == "__main__":
    main()
