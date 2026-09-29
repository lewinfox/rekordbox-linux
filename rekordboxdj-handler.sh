#!/usr/bin/env bash
# Host handler for rekordboxdj:// links (Spotify login redirects the browser to
# rekordboxdj://auth/redirect?...). Passes the link into the running container,
# where Wine hands it to rekordbox via the protocol registered in the prefix.
set -euo pipefail
url="${1:-}"
[[ $url == rekordboxdj://* ]] || { echo "not a rekordboxdj:// link: $url" >&2; exit 1; }

if ! docker ps --format '{{.Names}}' | grep -qx rekordbox; then
  notify-send "rekordbox" "rekordbox isn't running, so the login link can't be delivered." 2>/dev/null || true
  exit 1
fi

docker exec rekordbox bash -c '
  W=$HOME/.local/share/rekordbox-wine/wine/bin
  WINEPREFIX=$HOME/.local/share/rekordbox-wine/prefix WINESERVER=$W/wineserver WINEDEBUG=-all \
    exec $W/wine start "$1"' _ "$url"
