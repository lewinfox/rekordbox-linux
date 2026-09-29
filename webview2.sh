#!/usr/bin/env bash
# Install Microsoft Edge WebView2 into the rekordbox Wine prefix. rekordbox shows
# SoundCloud/Spotify/etc. logins in an embedded WebView2 window and says
# "reinstall rekordbox" when the runtime is missing. Needs Wine to report
# Windows 11. Run via `make webview2` with rekordbox closed.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

EXE=MicrosoftEdgeWebView2RuntimeInstallerX64.exe
CACHE=data/cache
mkdir -p "$CACHE"

if docker ps --format '{{.Names}}' | grep -qx rekordbox; then
  echo "rekordbox is running; close it first." >&2; exit 1
fi

if [[ ! -f $CACHE/$EXE ]] && ! ls "data/rekordbox-wine/prefix/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application/"[0-9]* >/dev/null 2>&1; then
  echo "==> Downloading the WebView2 standalone installer (~200 MB)"
  curl -fL --progress-bar -o "$CACHE/$EXE.part" "https://go.microsoft.com/fwlink/?linkid=2124701"
  mv "$CACHE/$EXE.part" "$CACHE/$EXE"
fi

./run.sh bash <<EOF
set -e
export WINEPREFIX=\$HOME/.local/share/rekordbox-wine/prefix
W=\$HOME/.local/share/rekordbox-wine/wine/bin
export WINESERVER=\$W/wineserver WINEDEBUG=err+all
echo "==> Windows version was: \$(WINEDEBUG=-all \$W/wine winecfg /v 2>&1 | tr -d "\\r")"
\$W/wine winecfg /v win11
echo "==> Windows version now: \$(WINEDEBUG=-all \$W/wine winecfg /v 2>&1 | tr -d "\\r")"
if ls "\$WINEPREFIX/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application/"[0-9]* >/dev/null 2>&1; then
  echo "==> WebView2 already installed; skipping the installer"
else
  echo "==> Running the WebView2 installer (silent; can take several minutes, errors show below)"
  \$W/wine \$HOME/.cache/$EXE /silent /install || echo "installer exit code: \$?"
fi
echo "==> Making WebView2 itself see Windows 7 (as Proton and Vinegar do); without it msedgewebview2.exe dies at startup"
\$W/wine reg add "HKCU\\\\Software\\\\Wine\\\\AppDefaults\\\\msedgewebview2.exe" /v Version /d win7 /f
echo "==> Disabling the Edge updater (its services never exit, and an update could break WebView2 under Wine)"
for svc in edgeupdate edgeupdatem; do
  \$W/wine reg add "HKLM\\\\System\\\\CurrentControlSet\\\\Services\\\\\$svc" /v Start /t REG_DWORD /d 4 /f
done
\$W/wine reg add "HKLM\\\\Software\\\\Policies\\\\Microsoft\\\\EdgeUpdate" /v UpdateDefault /t REG_DWORD /d 0 /f
\$W/wine reg add "HKLM\\\\Software\\\\Policies\\\\Microsoft\\\\EdgeUpdate" /v AutoUpdateCheckPeriodMinutes /t REG_DWORD /d 0 /f
echo "==> Stopping Wine"
\$W/wineserver -k
echo "==> Installed versions:"
ls "\$WINEPREFIX/drive_c/Program Files (x86)/Microsoft/EdgeWebView/Application/" 2>&1 || true
EOF
