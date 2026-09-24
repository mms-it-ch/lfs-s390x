#!/bin/bash
# Puts stage 1 together: the kernel of stage 0 with no initramfs, and the
# busybox tree as an ext4 file system on a 3390 volume, build/stage1.ckd -
# a rehearsal of where the LFS system is going to live.
#   KERNEL=lfs mkstage1.sh     the same with the kernel of config/lfs.config
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
top=${LFS_WORK:-$HOME/lfs-s390x}
root=$top/out/stage1-root
rm -rf "$root" && mkdir -p "$root"/{bin,sbin,usr/bin,usr/sbin,dev,proc,sys,tmp,etc,root}
cp "$here/initramfs/stage1/init" "$root/init" && chmod 755 "$root/init"
cp "$top/out/busybox/busybox" "$root/bin/busybox"
while read -r link; do
    [ "$link" = /bin/busybox ] || ln -sf /bin/busybox "$root$link"
done < "$top/out/busybox/busybox.links"

rm -f "$top/out/stage1.ext4"
mkfs.ext4 -q -F -L lfsroot -E root_owner=0:0 -d "$root" "$top/out/stage1.ext4" 32M
python3 "$here/tools/mkdasd.py" "$here/build/stage1.ckd" "$top/out/stage1.ext4" --cyls 100 --volser LFS001
# s390: a DASD is not used until it is set online, and dasd= is who does that
# before there is a user space to do it
python3 "$here/tools/mkins.py" "$here/build" stage1 "$top/out/${KERNEL:-stage0}/kernel.img" "" \
    "${CMDLINE:-ignore_loglevel panic=0 dasd=0.0.0120 root=/dev/dasda1 ro rootwait init=/init}"
