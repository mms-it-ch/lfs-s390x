#!/bin/bash
# 10.3 taken up again after an interrupted make - the step of ch9-11.sh from
# make on, in the tree the step left behind in /sources/10.3-kernel, and the
# stamp at the end. Inside the chroot: tools/lfs/chroot.sh BUILDER resume-kernel.sh
set -e
. /sources/scripts/common.sh
cd /sources/10.3-kernel
make
make modules_install
mkdir -pv /boot
cp -v arch/s390/boot/bzImage /boot/vmlinuz-7.1.8-lfs-13.1-systemd
cp -v System.map /boot/System.map-7.1.8
cp -v .config /boot/config-7.1.8
rm -rf /usr/share/doc/linux-7.1.8
cp -r Documentation -T /usr/share/doc/linux-7.1.8
cd /
rm -rf /sources/10.3-kernel
touch "$STAMPS/10.3-kernel"
echo "10.3-kernel is done"
