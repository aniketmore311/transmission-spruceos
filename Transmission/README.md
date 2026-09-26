# Transmission (SpruceOS app)

A self-contained SpruceOS wrapper around a static **aarch64** `transmission-daemon`
for the TrimUI Smart Pro S (and Smart Pro).

## What it does

The app menu offers:

- **Start Transmission** / **Stop Transmission** — controls the bundled daemon.
- **Torrent status** — lists every torrent (active first, with a **Show active only / Show all** toggle). Select one for full details and per-torrent actions:
  - **Resume / Pause**, **Verify**, **Reannounce**, **Remove** (keep files, or delete files)
- **Web UI (QR)** — shows a QR code for the web UI URL.
- **Log file location** — shows the paths of the daemon log and the app log.

The daemon is started in the background and **keeps running after you leave the
app**; it is only stopped with **Stop Transmission** (or on shutdown).

Both logs are plain files you can read over SSH; use **Log file location** to see
their paths. Each is rolled over to `.1` when it grows past ~1 MB.

## Paths

Everything the app owns lives in this directory:

| Item | Path |
|---|---|
| App / config dir | `/mnt/SDCARD/App/Transmission/` |
| Settings | `/mnt/SDCARD/App/Transmission/settings.json` |
| Log | `/mnt/SDCARD/App/Transmission/transmission.log` |
| App log | `/mnt/SDCARD/App/Transmission/transmission-app.log` |
| PID file | `/mnt/SDCARD/App/Transmission/transmission.pid` |
| Web UI assets | `/mnt/SDCARD/App/Transmission/web/` |
| Binary | `/mnt/SDCARD/App/Transmission/transmission-daemon` |

The **only** files written outside this directory are the downloads:

| Item | Path |
|---|---|
| Downloads | `/mnt/SDCARD/Roms/MEDIA/` |
| Incomplete downloads | `/mnt/SDCARD/Roms/MEDIA/.incomplete/` |

Both are created automatically the first time the app is launched.

## Web UI

While the daemon is running, open:

```
http://<device-ip>:9091/transmission/web/
```

Default credentials (change them!):

- username: `spruce`
- password: `happygaming`

To change them, edit `settings.json` (`rpc-username` / `rpc-password`) or use the
web UI's settings. Transmission hashes the password on first save.

## Config

On first launch, `settings.json.default` is copied to `settings.json`. After that
your `settings.json` is never overwritten, so edits and web-UI changes persist.
Delete `settings.json` to fall back to the defaults.

Notable defaults:

- Download dir: `/mnt/SDCARD/Roms/MEDIA`
- Incomplete dir: `/mnt/SDCARD/Roms/MEDIA/.incomplete`
- RPC: enabled on `0.0.0.0:9091`, authentication required
- Peer port: `51413`, UPnP/NAT-PMP port mapping disabled
- Log level: `info` (set on the command line by `launch.sh`)

## Adding torrents

Use the web UI (the **+** button / magnet links) — there is no on-device
"add torrent" UI in this version.

## Notes

- The app relies on the SpruceOS-provided `PyUI` and
  `spruce/scripts/helperFunctions.sh` for its UI, matching every other app.
- **Torrent status** reads the daemon's JSON-RPC on `127.0.0.1:9091` using the
  credentials in `settings.json.default`. If you change the web-UI password,
  update `settings.json.default` too, or the status screen will report an
  authentication error (logged in `transmission-app.log`).
