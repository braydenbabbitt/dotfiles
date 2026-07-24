#!/usr/bin/env python3
"""Auto-quit Zoom when its last window closes.

Zoom's Linux client is designed to hide-not-quit on window close: closing the
window keeps the process alive in the background so it can re-show its home
window instantly. There is no Zoom setting to change this, and on Hyprland there
is no tray to reach "Quit Zoom" — so the window just vanishes while the process
lives on. This watcher forces the behaviour we actually want: when the last Zoom
window closes, the Zoom process is terminated.

How it works: it connects to Hyprland's event socket (.socket2.sock) and reads
the event stream. On every `closewindow` (and `movewindow`, which can also
remove a Zoom window from the tree via a workspace hop) it asks Hyprland how
many windows of class "zoom" remain; when that hits zero it runs `pkill -x zoom`.

Why Python and not socat: socat/nc are not installed on this machine, but
python3 is. Stdlib sockets are enough, so this needs no extra packages.

Launched from hyprland.conf via exec-once (mirrors the caps-lock watcher). It is
event-driven, not polling. If Hyprland restarts, its instance signature changes
and this socket dies — fine, because exec-once re-runs the watcher on start.

We NEVER kill by process group (a window's pgid can include the shell that
started the Hyprland session; killing that group takes down the compositor).
`pkill -x zoom` is an exact match on the process name and is safely scoped.
"""
import os
import socket
import subprocess
import sys
import time

# Events after which the number of live Zoom windows may have dropped to zero.
# closewindow: a window was destroyed. movewindow: a window changed workspace
# (Zoom's home window closing sometimes surfaces as a move off-tree first).
TRIGGER_EVENTS = ("closewindow", "movewindow")


def socket_path():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    runtime = os.environ.get("XDG_RUNTIME_DIR")
    if not sig or not runtime:
        return None
    return os.path.join(runtime, "hypr", sig, ".socket2.sock")


def zoom_window_count():
    """Number of live windows with class 'zoom', or None if the query failed."""
    try:
        out = subprocess.run(
            ["hyprctl", "clients", "-j"],
            capture_output=True, text=True, timeout=5,
        ).stdout
    except (subprocess.SubprocessError, OSError):
        return None
    # Avoid a hard dependency on jq by parsing the JSON ourselves.
    import json
    try:
        clients = json.loads(out)
    except ValueError:
        return None
    return sum(1 for c in clients if c.get("class") == "zoom")


def quit_zoom():
    # -TERM first, escalate to -KILL for anything that ignores it.
    subprocess.run(["pkill", "-TERM", "-x", "zoom"], check=False)
    time.sleep(2)
    if subprocess.run(["pgrep", "-x", "zoom"], check=False,
                      capture_output=True).returncode == 0:
        subprocess.run(["pkill", "-KILL", "-x", "zoom"], check=False)


def connect():
    """Block until the Hyprland event socket is connectable; return the socket."""
    while True:
        path = socket_path()
        if path and os.path.exists(path):
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.connect(path)
                return s
            except OSError:
                pass
        time.sleep(1)


def run():
    # Only act once per "drop to zero" so we don't re-pkill on later stray events
    # while Zoom is already gone.
    zoom_was_present = False
    sock = connect()
    buf = b""
    while True:
        try:
            data = sock.recv(4096)
        except OSError:
            data = b""
        if not data:  # socket closed (e.g. Hyprland restarted) — reconnect.
            sock.close()
            sock = connect()
            buf = b""
            continue
        buf += data
        while b"\n" in buf:
            line, buf = buf.split(b"\n", 1)
            event = line.decode("utf-8", "replace").split(">>", 1)[0]
            if event not in TRIGGER_EVENTS:
                continue
            count = zoom_window_count()
            if count is None:
                continue
            if count > 0:
                zoom_was_present = True
            elif zoom_was_present:
                # Last Zoom window just closed — kill the lingering process.
                quit_zoom()
                zoom_was_present = False


if __name__ == "__main__":
    try:
        run()
    except KeyboardInterrupt:
        sys.exit(0)
