#!/bin/bash
set -e
top=${LFS_WORK:-$HOME/lfs-s390x}
mkdir -p "$top/build" && cd "$top/build"
[ -d linux-7.1.8 ] || tar xf ../sources/linux-7.1.8.tar.xz
[ -d busybox-1.37.0 ] || tar xf ../sources/busybox-1.37.0.tar.bz2
cd linux-7.1.8
echo "== march choices"; grep -n "^config MARCH_\|^config TUNE_" arch/s390/Kconfig | head -30
echo "== defconfigs"; ls arch/s390/configs
echo "== gen_facilities (head)"; sed -n '1,140p' arch/s390/tools/gen_facilities.c
