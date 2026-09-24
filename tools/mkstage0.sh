#!/bin/bash
# Puts stage 0 together: kernel, busybox initramfs and build/stage0.ins on
# the Windows side, where Hercules reads them.
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
top=${LFS_WORK:-$HOME/lfs-s390x}
work=$top/out/stage0-root
rm -rf "$work" && mkdir -p "$work/bin"
cp -r "$here/initramfs/stage0/." "$work/"
cp "$top/out/busybox/busybox" "$work/bin/busybox"
python3 "$here/tools/mkinitramfs.py" "$top/out/stage0/initrd.cpio" "$work" --links "$top/out/busybox/busybox.links"
python3 "$here/tools/mkins.py" "$here/build" stage0 "$top/out/stage0/kernel.img" "$top/out/stage0/initrd.cpio" \
    "${CMDLINE:-ignore_loglevel panic=0 rdinit=/init}"
cp "$top/out/stage0/System.map" "$here/build/stage0.map"
