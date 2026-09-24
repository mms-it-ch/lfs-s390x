#!/bin/bash
# LFS 7.2 to 7.4, as root: hands $LFS over to root, mounts the kernel's file
# systems into it and runs one of the chapter scripts inside - or a shell, if
# none is named. Everything in there is an s390x program; what runs it is the
# kernel's binfmt_misc entry for qemu-s390x, registered with the F flag, so
# the emulator needs no copy inside the tree.
#
#   chroot.sh BUILDER [SCRIPT [ARGS]]     SCRIPT is a name in tools/lfs
set -e
builder=${1:?who owned the tree while chapters 5 and 6 were built}
shift
here=$(cd "$(dirname "$0")" && pwd)
export LFS=${LFS:-/mnt/lfs}

grep -q enabled /proc/sys/fs/binfmt_misc/qemu-s390x || {
    echo "no binfmt_misc entry for qemu-s390x - apt install qemu-user-static"; exit 1; }

chown --from "$builder" -R root:root $LFS/{usr,var,etc,tools} 2>/dev/null || true

mkdir -p $LFS/{dev,proc,sys,run}
release() {
    mountpoint -q $LFS/dev/shm && umount $LFS/dev/shm
    for m in dev/pts sys proc run dev; do
        mountpoint -q $LFS/$m && umount $LFS/$m
    done
    return 0
}
trap release EXIT
mountpoint -q $LFS/dev     || mount --bind /dev $LFS/dev
mountpoint -q $LFS/dev/pts || mount -t devpts devpts -o gid=5,mode=0620 $LFS/dev/pts
mountpoint -q $LFS/proc    || mount -t proc proc $LFS/proc
mountpoint -q $LFS/sys     || mount -t sysfs sysfs $LFS/sys
mountpoint -q $LFS/run     || mount -t tmpfs tmpfs $LFS/run
if [ -h $LFS/dev/shm ]; then
    install -d -m 1777 $LFS$(realpath /dev/shm)
else
    mountpoint -q $LFS/dev/shm || mount -t tmpfs -o nosuid,nodev tmpfs $LFS/dev/shm
fi

# The scripts go in with the sources, which is the one place both sides see
cp "$here"/../../patches/*.patch $LFS/sources/
# and the kernel configuration fragments, for 10.3
mkdir -p $LFS/sources/config && cp "$here"/../../config/*.config $LFS/sources/config/
rm -rf $LFS/sources/scripts && cp -r "$here" $LFS/sources/scripts

if [ $# -eq 0 ]; then
    set -- /bin/bash --login
else
    script=$1; shift
    set -- /bin/bash /sources/scripts/$script "$@"
fi
chroot "$LFS" /usr/bin/env -i   \
    HOME=/root                  \
    TERM="${TERM:-linux}"       \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin     \
    MAKEFLAGS="-j$(nproc)"      \
    TESTSUITEFLAGS="-j$(nproc)" \
    LFS=                        \
    "$@"
