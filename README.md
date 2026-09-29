# rekordbox in Docker

Rekordbox 7.2.x on Linux, using the Wine patches from
[MrNorm/rekordbox-wine](https://github.com/MrNorm/rekordbox-wine) (pinned to `74dd927`),
built into an Ubuntu 24.04 image with wine-staging 11.16.

## Use

```sh
make install                  # interactive: image, host setup, rekordbox, desktop launcher
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
