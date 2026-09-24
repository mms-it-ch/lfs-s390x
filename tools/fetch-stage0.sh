#!/bin/bash
# Stage 0 sources: the kernel of LFS 13.1 and busybox for a first initramfs.
# Everything lives on the Linux side of WSL - NTFS is too slow and folds case.
set -e
top=${LFS_WORK:-$HOME/lfs-s390x}
mkdir -p "$top/sources" && cd "$top/sources"

kernel=linux-7.1.8.tar.xz
busybox=busybox-1.37.0.tar.bz2

[ -f $kernel ] || wget -nv https://www.kernel.org/pub/linux/kernel/v7.x/$kernel
[ -f sha256sums.asc ] || wget -nv -O sha256sums.asc https://www.kernel.org/pub/linux/kernel/v7.x/sha256sums.asc
grep " $kernel\$" sha256sums.asc | sha256sum -c -

[ -f $busybox ] || wget -nv https://busybox.net/downloads/$busybox
[ -f $busybox.sha256 ] || wget -nv https://busybox.net/downloads/$busybox.sha256
sha256sum -c $busybox.sha256
ls -la
