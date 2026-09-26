#!/usr/bin/env python3
"""Build the PyUI OPTION_LIST menu JSON for the Transmission app.

Usage:
    menu_builder.py main <out.json> <status> <action_label> <action_token>

The option list is a flat JSON object mapping a display label to the value that
PyUI writes to selection.txt when it is chosen. PyUI treats '/' in a key as a
sub-menu separator, so generated keys have '/' replaced with '|'.
"""
import json
import sys


def _write(path, menu):
    with open(path, "w", encoding="utf-8") as handle:
        json.dump(menu, handle, ensure_ascii=False)


def build_main(path, status, action_label, action_token):
    # PyUI treats '/' in a key as a sub-menu separator; keep keys flat.
    status = status.replace("/", "|")
    action_label = action_label.replace("/", "|")
    menu = {
        status: "ACTION_NONE",
        action_label: action_token,
        "Log file location": "ACTION_LOG_PATH",
    }
    _write(path, menu)


def main():
    if len(sys.argv) < 6 or sys.argv[1] != "main":
        sys.exit("usage: menu_builder.py main <out.json> <status> <action_label> <action_token>")
    build_main(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5])


if __name__ == "__main__":
    main()
