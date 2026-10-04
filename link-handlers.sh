#!/usr/bin/env bash
# Register rekordboxdj:// links, used by Spotify's login redirect:
#  - in the Wine prefix, pointing at the installed rekordbox.exe (without it,
#    rekordbox says "reinstall rekordbox" before opening the Spotify login);
#  - on the host, so the browser hands rekordboxdj:// links to
#    rekordboxdj-handler.sh, which passes them into the running container.
# Re-run after a rekordbox update: the prefix entry names the versioned exe path.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
ROOT="$PWD"
source ./paths.sh
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"

exe="$(ls -d "$PREFIX/drive_c/Program Files/rekordbox/rekordbox "*/rekordbox.exe 2>/dev/null | sort -V | tail -1)"
[[ -n $exe ]] || { echo "rekordbox isn't installed yet; install it first." >&2; exit 1; }
if docker ps --format '{{.Names}}' | grep -qx rekordbox; then
  echo "rekordbox is running; close it first." >&2; exit 1
fi

# Windows path of the exe, e.g. C:\Program Files\rekordbox\rekordbox 7.2.19\rekordbox.exe
win="C:\\${exe#"$PREFIX/drive_c/"}"; win="${win//\//\\}"
echo "==> Registering rekordboxdj:// in the prefix -> $win"
./run.sh bash <<EOF
set -e
W=\$HOME/.local/share/rekordbox-wine/wine/bin
export WINEPREFIX=\$HOME/.local/share/rekordbox-wine/prefix WINESERVER=\$W/wineserver WINEDEBUG=-all
K='HKLM\\Software\\Classes\\rekordboxdj'
\$W/wine reg add "\$K" /ve /d "URL:rekordboxdj" /f
\$W/wine reg add "\$K" /v "URL Protocol" /d "" /f
\$W/wine reg add "\$K\\DefaultIcon" /ve /d '"$win",0' /f
\$W/wine reg add "\$K\\shell\\open\\command" /ve /d '"$win" %1' /f
\$W/wineserver -k
EOF

echo "==> Registering the host handler for rekordboxdj:// links"
install -Dm644 /dev/stdin "$APPS/rekordboxdj-handler.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=rekordbox link handler
Exec=$ROOT/rekordboxdj-handler.sh %u
MimeType=x-scheme-handler/rekordboxdj;
NoDisplay=true
Terminal=false
EOF
xdg-mime default rekordboxdj-handler.desktop x-scheme-handler/rekordboxdj
update-desktop-database -q "$APPS" 2>/dev/null || true
echo "    $(xdg-mime query default x-scheme-handler/rekordboxdj)"
