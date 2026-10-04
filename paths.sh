# Where things live on the host, in the XDG folders. Sourced by the other scripts.
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/rekordbox-wine"   # Wine prefix, patched Wine, rekordbox library
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/rekordbox-wine"       # downloads, the container's ~/.cache
RUNTIME="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
PREFIX="$DATA/prefix"
# The music folder from xdg-user-dirs (xdg-user-dir prints $HOME when none is set).
if [[ -z ${MUSIC:-} ]]; then
  MUSIC="$(xdg-user-dir MUSIC 2>/dev/null || true)"
  [[ -n $MUSIC && $MUSIC != "$HOME" ]] || MUSIC="$HOME/Music"
fi

# Older checkouts kept everything in ./data. Stop rather than start an empty library.
if [[ -d data/rekordbox-wine && ! -d $DATA ]]; then
  echo "rekordbox's data is still in $PWD/data; move it to $DATA first:" >&2
  echo "  mv data/rekordbox-wine '$DATA' && mkdir -p '$CACHE' && mv data/cache/* '$CACHE/'" >&2
  exit 1
fi
