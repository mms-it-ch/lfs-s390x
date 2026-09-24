#!/bin/bash
# busybox as one static s390x program, for the initramfs of stage 0.
set -e
top=${LFS_WORK:-$HOME/lfs-s390x}
src=$top/build/busybox-1.37.0
obj=$top/build/busybox-obj
out=$top/out/busybox
mk="make -C $src O=$obj ARCH=s390 CROSS_COMPILE=s390x-linux-gnu- -j$(nproc)"

mkdir -p "$obj" "$out"
if [ ! -f "$obj/.config" ]; then
    $mk defconfig >/dev/null
    # 1.37.0 offers its x86 SHA acceleration to every architecture and then
    # does not compile; tc does not compile against current kernel headers
    sed -i -e 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' \
           -e 's/^CONFIG_TC=y/# CONFIG_TC is not set/' \
           -e 's/^CONFIG_SHA1_HWACCEL=y/# CONFIG_SHA1_HWACCEL is not set/' \
           -e 's/^CONFIG_SHA256_HWACCEL=y/# CONFIG_SHA256_HWACCEL is not set/' \
           -e 's/^CONFIG_FEATURE_HAVE_RPC=y/# CONFIG_FEATURE_HAVE_RPC is not set/' \
           -e 's/^CONFIG_FEATURE_INETD_RPC=y/# CONFIG_FEATURE_INETD_RPC is not set/' "$obj/.config"
    yes "" | $mk oldconfig >/dev/null
fi
$mk busybox busybox.links 2>&1 | tail -5
cp "$obj/busybox" "$obj/busybox.links" "$out/"
file "$out/busybox"
