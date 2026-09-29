#!/usr/bin/env bash
# One-off host changes the container can't make for itself. Run with sudo.
# Undo: rm the three files below and reboot.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo"; exit 1; }

# 1. Fast Wine sync primitives in the kernel (big CPU/UI win), now and every boot.
modprobe ntsync
echo ntsync > /etc/modules-load.d/rekordbox-wine.conf

# 2. snd_seq_dummy makes rekordbox bind a fake MIDI port instead of the DDJ-400.
modprobe -r snd_seq_dummy || echo "snd_seq_dummy busy; it'll be gone after a reboot"
echo 'blacklist snd_seq_dummy' > /etc/modprobe.d/rekordbox-wine.conf

# 3. Let the audio group open Pioneer HID devices (the container user is in it).
echo 'KERNEL=="hidraw*", ATTRS{idVendor}=="2b73", MODE="0660", GROUP="audio", TAG+="uaccess"' \
  > /etc/udev/rules.d/60-pioneer-ddj.rules
udevadm control --reload-rules

echo "done. Replug the DDJ-400 if it's connected."
