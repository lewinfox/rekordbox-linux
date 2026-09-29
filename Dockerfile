# rekordbox 7.2.x under patched wine-staging 11.16, via github.com/MrNorm/rekordbox-wine.
# Build:  ./build.sh      Run:  ./run.sh
FROM ubuntu:24.04

ARG WINE_PKG_VER=11.16~noble-1
ARG RBW_COMMIT=74dd927
ARG UID=1000
ARG GID=1000

ENV DEBIAN_FRONTEND=noninteractive

# WineHQ repo, wine-staging pinned to the one version the patch series fits.
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && mkdir -p /etc/apt/keyrings \
 && curl -fsSL https://dl.winehq.org/wine-builds/winehq.key \
    | gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key \
 && curl -fsSL -o /etc/apt/sources.list.d/winehq-noble.sources \
    https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources \
 && apt-get update \
 && apt-get install -y --install-recommends \
    winehq-staging=$WINE_PKG_VER wine-staging=$WINE_PKG_VER \
    wine-staging-amd64=$WINE_PKG_VER wine-staging-i386:i386=$WINE_PKG_VER \
 && apt-mark hold winehq-staging wine-staging wine-staging-amd64 wine-staging-i386:i386 \
 && rm -rf /var/lib/apt/lists/*

# Build tools (from packaging/debian/control) plus runtime helpers.
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git make gcc clang lld python3 flex bison binutils xz-utils patch file \
    devscripts debhelper \
    libx11-dev libxext-dev libxrandr-dev libxcomposite-dev libxfixes-dev \
    libxi-dev libxcursor-dev libxrender-dev libxinerama-dev \
    libasound2-dev libdbus-1-dev libfreetype-dev libgnutls28-dev \
    libusb-1.0-0-dev libudev-dev libfontconfig-dev \
    libgl-dev libegl-dev libvulkan-dev libxxf86vm-dev libxkbcommon-dev libxshmfence-dev \
    alsa-utils pipewire-alsa pulseaudio-utils usbutils kmod \
    fonts-noto-core fonts-liberation2 xdg-utils \
 && rm -rf /var/lib/apt/lists/*

# Build and install the rekordbox-wine package (20-30 min: compiles patched Wine parts).
RUN git clone https://github.com/MrNorm/rekordbox-wine.git /src/rekordbox-wine \
 && cd /src/rekordbox-wine && git checkout $RBW_COMMIT \
 && packaging/build-deb.sh /src/dist \
 && apt-get update && apt-get install -y /src/dist/rekordbox-wine_*.deb \
 && strings /usr/share/rekordbox-wine/winedll/winex11.so | grep -q eglGetProcAddress \
    || { echo "patched winex11.so has no OpenGL support (missing GL/EGL -dev headers)"; exit 1; } \
 && rm -rf /var/lib/apt/lists/*

# Wine's .NET (Mono) and browser (Gecko) add-ons, in the shared folder Wine checks
# first, so new prefixes don't prompt to download them. Versions must match Wine.
ARG MONO_VER=11.3.0
ARG GECKO_VER=2.47.4
RUN d=/opt/wine-staging/share/wine \
 && mkdir -p $d/mono $d/gecko \
 && curl -fsSL https://dl.winehq.org/wine/wine-mono/$MONO_VER/wine-mono-$MONO_VER-x86.tar.xz | tar -xJ -C $d/mono \
 && for a in x86 x86_64; do \
      curl -fsSL https://dl.winehq.org/wine/wine-gecko/$GECKO_VER/wine-gecko-$GECKO_VER-$a.tar.xz | tar -xJ -C $d/gecko; \
    done

# Mesa OpenGL/Vulkan drivers: wined3d (Direct3D) renders through these.
RUN apt-get update && apt-get install -y --no-install-recommends unzip mesa-utils vulkan-tools \
    libgl1 libglx-mesa0 libegl1 libegl-mesa0 libgl1-mesa-dri mesa-vulkan-drivers libvulkan1 \
    libgl1:i386 libglx-mesa0:i386 libegl1:i386 libegl-mesa0:i386 libgl1-mesa-dri:i386 mesa-vulkan-drivers:i386 libvulkan1:i386 && rm -rf /var/lib/apt/lists/*

# GStreamer decoders: Wine decodes MP3/AAC through these (plugins-base alone reads no MP3).
# icoutils: pulls the app icon out of rekordbox.exe for the desktop launcher.
RUN apt-get update && apt-get install -y --no-install-recommends \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-ugly gstreamer1.0-libav gstreamer1.0-tools \
    icoutils \
 && rm -rf /var/lib/apt/lists/*

# Non-root user matching the host uid, in the host's audio group (gid 29).
RUN (userdel -r ubuntu 2>/dev/null || true) \
 && groupadd -g $GID dj && useradd -m -u $UID -g $GID -G audio -s /bin/bash dj
RUN install -d -o dj -g dj -m 700 /run/user/$UID
COPY files/xdg-open /usr/local/bin/xdg-open
USER dj
WORKDIR /home/dj
ENV WINEDEBUG=-all XDG_RUNTIME_DIR=/run/user/1000

CMD ["rekordbox-wine"]
