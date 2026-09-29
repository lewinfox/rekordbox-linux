#!/usr/bin/env bash
# Run rekordbox in the container. Arguments go to rekordbox-wine:
#   ./run.sh --install    download + install rekordbox (first time)
#   ./run.sh --check      report problems, change nothing
#   ./run.sh              launch
#   ./run.sh bash         a shell inside the container
# Plug the DDJ-400 in BEFORE starting: Docker only sees devices present at start.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

DATA="$PWD/data"          # Wine prefix + rekordbox library/settings
mkdir -p "$DATA/rekordbox-wine" "$DATA/cache"
MUSIC="${MUSIC:-$HOME/Music}"
RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

args=(
  --rm --name rekordbox
  --network host                               # OAuth logins redirect the browser to 127.0.0.1:5500x
  --ipc=host                                   # X11 shared memory
  --cap-add SYS_NICE --ulimit rtprio=95 --ulimit memlock=-1
  # screen (XWayland)
  -e DISPLAY="${DISPLAY:-:0}" -v /tmp/.X11-unix:/tmp/.X11-unix:ro
  # sound: raw ALSA for the controller, PipeWire for the laptop speakers
  --device /dev/snd
  # USB + device enumeration (wineusb, winebus)
  -v /dev/bus/usb:/dev/bus/usb --device-cgroup-rule='c 189:* rmw'
  -v /run/udev:/run/udev:ro
  # data
  -v "$DATA/rekordbox-wine:/home/dj/.local/share/rekordbox-wine"
  -v "$DATA/cache:/home/dj/.cache"
  -v "$MUSIC:/home/dj/Music"
)

# X auth cookie (GNOME/mutter keeps XWayland's in XDG_RUNTIME_DIR)
if [[ -n "${XAUTHORITY:-}" && -f "$XAUTHORITY" ]]; then
  args+=(-v "$XAUTHORITY:/tmp/xauth:ro" -e XAUTHORITY=/tmp/xauth)
fi
[[ -S "$RUNTIME/pipewire-0" ]]   && args+=(-v "$RUNTIME/pipewire-0:/run/pipewire-0" -e PIPEWIRE_REMOTE=/run/pipewire-0)
[[ -S "$RUNTIME/pulse/native" ]] && args+=(-v "$RUNTIME/pulse/native:/run/pulse-native" -e PULSE_SERVER=unix:/run/pulse-native)
[[ -S /run/dbus/system_bus_socket ]] && args+=(-v /run/dbus/system_bus_socket:/run/dbus/system_bus_socket)
[[ -d /media/$USER ]] && args+=(-v "/media/$USER:/media/$USER:rslave")   # USB sticks for export

# GPU, in the host's video/render groups
[[ -d /dev/dri ]] && args+=(--device /dev/dri)
for g in video render; do gid="$(getent group $g | cut -d: -f3)" && args+=(--group-add "$gid"); done

# Fast Wine sync (sudo modprobe ntsync) and the controller's HID nodes
[[ -e /dev/ntsync ]] && args+=(--device /dev/ntsync)
for h in /dev/hidraw*; do [[ -e $h ]] && args+=(--device "$h"); done

[[ -n "${WINEDEBUG:-}" ]] && args+=(-e WINEDEBUG="$WINEDEBUG")
# e.g. --remote-debugging-port=9222 to inspect rekordbox's embedded web panes
[[ -n "${WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS:-}" ]] && args+=(-e WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS)
if [[ -t 0 ]]; then args+=(-it); elif [[ "${1:-}" == bash ]]; then args+=(-i); fi   # -i: allow piping commands into ./run.sh bash

# Browser bridge: the container's xdg-open writes URLs to this FIFO, and we open
# http(s) ones in the host browser (logins to SoundCloud etc.). Nothing else is
# accepted, so the container can't make the host open files or run handlers.
BRIDGE="$DATA/open-url.fifo"
rm -f "$BRIDGE" && mkfifo -m 600 "$BRIDGE"
args+=(-v "$BRIDGE:/run/open-url")
(
  # Outer loop reopens the FIFO after each writer closes it (EOF).
  while true; do
    while read -r url; do
      case "$url" in
        http://*|https://*) xdg-open "$url" >/dev/null 2>&1 & ;;
        *) echo "run.sh: ignored non-web URL from container: $url" >&2 ;;
      esac
    done < "$BRIDGE"
  done
) &
LISTENER=$!
trap 'kill $LISTENER 2>/dev/null; rm -f "$BRIDGE"' EXIT

if [[ "${1:-}" == bash ]]; then
  docker run "${args[@]}" rekordbox-wine bash
else
  docker run "${args[@]}" rekordbox-wine rekordbox-wine "$@"
fi
