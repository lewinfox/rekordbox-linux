#!/usr/bin/env bash
# Interactive installer: build the image, set up the host, install rekordbox,
# add a desktop launcher. Asks before each step. Run via `make install`.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"
ROOT="$PWD"
IMAGE=rekordbox-wine
PREFIX="$ROOT/data/rekordbox-wine/prefix"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor"

bold() { printf '\n\033[1m%s\033[0m\n' "$*"; }
ask()  { local r; read -r -p "$1 [Y/n] " r; [[ -z $r || $r =~ ^[Yy] ]]; }

rekordbox_exe() {
  ls -d "$PREFIX/drive_c/Program Files/rekordbox/rekordbox "*/rekordbox.exe 2>/dev/null | sort -V | tail -1
}

# 1. Image -------------------------------------------------------------------
bold "1/4  Build the Docker image"
if docker image inspect $IMAGE >/dev/null 2>&1; then
  echo "An image '$IMAGE' already exists. Rebuilding is quick unless the Dockerfile's early steps changed."
else
  echo "First build compiles the patched Wine parts: about 15-20 minutes."
fi
if ask "Build the image now?"; then
  make container
fi

# 2. Host setup --------------------------------------------------------------
bold "2/4  Host setup (needs sudo)"
echo "Loads ntsync, blacklists snd_seq_dummy, and adds a udev rule for Pioneer controllers."
echo "Writes three files under /etc; see host-setup.sh."
if ask "Run host-setup.sh with sudo now?"; then
  sudo "$ROOT/host-setup.sh"
fi

# 3. rekordbox itself --------------------------------------------------------
bold "3/4  Install rekordbox"
if exe="$(rekordbox_exe)" && [[ -n $exe ]]; then
  echo "Already installed: ${exe#"$PREFIX/drive_c/"}"
  echo "(rekordbox updates itself from inside the app.)"
else
  echo "Downloads the latest rekordbox (~660 MB) from rekordbox.com into data/."
  echo "A language dialog will appear: press Return."
  if ask "Download and install rekordbox now?"; then
    "$ROOT/run.sh" --install --latest
  fi
fi

# 4. Desktop launcher --------------------------------------------------------
bold "4/4  Desktop launcher"
echo "Adds 'rekordbox' to your app menu, with the icon taken from rekordbox.exe."
if ask "Install the desktop launcher?"; then
  exe="$(rekordbox_exe)"
  if [[ -z $exe ]]; then
    echo "rekordbox isn't installed yet, so there's no icon to extract; skipping. Re-run 'make install' after step 3."
  else
    # Extract every size from rekordbox.exe into a scratch dir, then install them
    # into the per-user icon theme (XDG standard location).
    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
    docker run --rm -v "$(dirname "$exe"):/rb:ro" -v "$tmp:/out" $IMAGE \
      bash -c 'cd /out && wrestool -x -t 14 /rb/rekordbox.exe -o rb.ico && icotool -x rb.ico'
    for png in "$tmp"/rb_*x32.png; do
      s="$(basename "$png" | sed -E 's/rb_[0-9]+_([0-9]+)x.*/\1/')"
      install -Dm644 "$png" "$ICONS/${s}x${s}/apps/rekordbox.png"
      echo "  $ICONS/${s}x${s}/apps/rekordbox.png"
    done
    touch "$ICONS"   # newer mtime makes GTK/GNOME rescan the theme dir
    install -Dm644 /dev/stdin "$APPS/rekordbox.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=rekordbox
Comment=rekordbox 7 in Docker (patched Wine)
Exec=$ROOT/run.sh
Icon=$ICONS/256x256/apps/rekordbox.png
Terminal=false
Categories=AudioVideo;Audio;Music;
StartupWMClass=rekordbox.exe
EOF
    gtk-update-icon-cache -q "$ICONS" 2>/dev/null || true
    update-desktop-database -q "$APPS" 2>/dev/null || true
    echo "Installed $APPS/rekordbox.desktop"
  fi
fi

# Done -----------------------------------------------------------------------
bold "Next"
cat <<EOF
  Launch:        rekordbox from the app menu, or $ROOT/run.sh
  Health check:  $ROOT/run.sh --check
  Controller:    plug the DDJ-400 in BEFORE launching (Docker only sees devices present at start)
  Music:         ~/Music appears in rekordbox as C:\\users\\dj\\Music
                 (File > Import > Import Folder)
  Data:          $ROOT/data  (Wine prefix + rekordbox library; back this up)
EOF
