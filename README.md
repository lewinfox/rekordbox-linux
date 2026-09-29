# rekordbox in Docker

Rekordbox 7.2.x on Linux, using the Wine patches from
[MrNorm/rekordbox-wine](https://github.com/MrNorm/rekordbox-wine) (pinned to `74dd927`),
built into an Ubuntu 24.04 image with wine-staging 11.16.

## Use

```sh
make install                  # interactive: image, host setup, rekordbox, WebView2, link handlers, launcher
make container                # just (re)build the image
./run.sh                      # launch (or "rekordbox" in the app menu)
./run.sh --check              # health check
./run.sh bash                 # shell in the container
```

Plug the DDJ-400 in before `./run.sh`: Docker only sees devices present at start.
The Wine prefix and rekordbox library live in `data/`. `~/Music` is shared in and
appears in rekordbox as `C:\users\dj\Music`.

## Gotchas found getting this working on Ubuntu

- **Login screen freezes**: the upstream Debian build deps lack `libgl-dev`/`libegl-dev`,
  so the patched `winex11.so` builds without OpenGL, Direct3D can't start, and rekordbox
  never repaints. The Dockerfile adds them and fails the build if `winex11.so` lacks EGL.
- **MP3s fail to analyse** (`FileReader.cpp:102`): Wine decodes through GStreamer, and
  `plugins-base` alone can't read MP3. Needs `plugins-good`/`ugly`/`libav`.
- The container also needs Mesa GL/Vulkan drivers, and audio sockets mounted outside
  `XDG_RUNTIME_DIR` (Docker creates their parent dirs as root, which PulseAudio rejects).
- After changing the patched Wine files, delete `data/rekordbox-wine/wine`; the launcher
  rebuilds its private Wine tree but only checks patch markers, not contents.
- `--check` warnings about udev rules, ntsync-at-boot and rtkit look inside the container;
  `host-setup.sh` handles them on the host.

## USB sticks and controller hotplug

- Sticks must be **FAT32** (Wine can't report exFAT, so rekordbox rejects it as badly
  formatted). One msdos partition, FAT32, e.g. labelled `REKORDBOX`.
- `files/devmirror` runs as root in the container (started by `run.sh`) and mirrors
  host `/dev/sd*` (read-only) and Pioneer-only `/dev/hidraw*` nodes from sysfs as devices
  come and go. Wine only gives a stick a drive letter if its `/dev/sdX1` exists, and
  detects FAT32 by reading its boot sector. Keyboards etc. get no hidraw node.
- `run.sh` runs the container with AppArmor unconfined so Wine can reach UDisks on the
  system D-Bus, and bind-mounts `/dev/snd` so a controller plugged in later appears.
- **Known issue:** a stick already plugged in at launch can be missed, because Wine scans
  before devmirror's first pass. Replug it, or add the startup wait (see git log).

## Streaming-service logins

- **SoundCloud, Beatport: work.** rekordbox opens the login in the host browser (via
  `files/xdg-open` and the FIFO in `run.sh`), which redirects to
  `http://localhost:5500x/redirect.html`; `--network host` lets that reach rekordbox.
  Needs WebView2 (`make webview2`), without which rekordbox says "reinstall rekordbox".
- **Spotify: not working yet.** It redirects to `rekordboxdj://auth/redirect?code=...`.
  Getting that far needs the `rekordboxdj` protocol registered in the prefix and
  `rekordboxdj-handler.sh` registered on the host as the `x-scheme-handler/rekordboxdj`
  handler (`make links`, or step 5 of `make install`; re-run after a rekordbox update). The link then reaches the running rekordbox intact (a second rekordbox.exe
  sends it by WM_COPYDATA to the main instance's `JUCEWindow`), but rekordbox never acts
  on it. Cause unknown.
- WebView2's own process (`msedgewebview2.exe`) still exits at startup when a service pane
  opens, even with the per-app Windows 7 override Proton uses. Logins that work don't
  seem to need it.
- Debugging: `WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS=--remote-debugging-port=9222 ./run.sh`
  exposes DevTools for the embedded panes (once WebView2 stays up).
