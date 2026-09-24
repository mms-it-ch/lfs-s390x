#!/bin/bash
# As root: turns the tree in $LFS into a 3390 volume and an .ins file to load
# its kernel from - what LFS 10.4 and 11.3 are on a PC, where the tree already
# is the disk and GRUB finds the kernel on it.
#
#   mklfs.sh [VOLUME-DIRECTORY]      default: build/ - a 3390-9 is 8.5 GB, and
#                                    drive C: has been full once already
#
# The tree goes through a copy without /sources and /tools into an ext4 image
# (mkfs.ext4 -d, which keeps owners and modes when root runs it), the image
# into a volume (tools/mkdasd.py), and the kernel of tools/build-kernel.sh lfs
# into build/lfs.ins. No initramfs: the DASD driver and ext4 are in the kernel.
set -e
here=$(cd "$(dirname "$0")/.." && pwd)
export LFS=${LFS:-/mnt/lfs}
work=${LFS_WORK:-$HOME/lfs-s390x}
where=${1:-$here/build}
stage=$work/out/lfs-root

for m in dev/pts dev/shm dev proc sys run; do
    mountpoint -q $LFS/$m && { echo "$LFS/$m is still mounted - is a chroot running?"; exit 1; }
done
[ -f $LFS/sources/stamps/11.1-the-end ] || { echo "chapters 9 to 11 have not been run"; exit 1; }

echo "== copying the tree"
rm -rf "$stage" && mkdir -p "$stage"
tar -C $LFS --one-file-system --exclude=./sources --exclude=./tools -cpf - . | tar -C "$stage" -xpf -
mkdir -p "$stage"/{dev,proc,sys,run,tmp,sources}
# The kernel: the tree's own, built in the chroot by 10.3 since 23.09.2026;
# before that the cross-built one of tools/build-kernel.sh, which still
# stands in when the tree has none
kernel="$stage/boot/vmlinuz-7.1.8-lfs-13.1-systemd"
if [ -f "$kernel" ]; then
    echo "== the kernel of 10.3, $(stat -c %s "$kernel") bytes, $(ls "$stage/lib/modules" | head -1) with modules"
else
    echo "== no kernel in the tree - the cross-built one"
    cp "$work/out/lfs/kernel.img" "$kernel"
    cp "$work/out/lfs/System.map" "$stage/boot/System.map-7.1.8"
    cp "$work/out/lfs/.config"    "$stage/boot/config-7.1.8"
fi
cp "$kernel" "$work/out/lfs-kernel.img"
cp "$stage/boot/System.map-7.1.8" "$work/out/lfs-System.map"

used=$(du -sm "$stage" | cut -f1)
size=$(( used * 13 / 10 + 256 ))
echo "== $used MB in the tree, a file system of $size MB"
rm -f "$work/out/lfs.ext4"
mkfs.ext4 -q -F -L lfsroot -d "$stage" "$work/out/lfs.ext4" ${size}M
rm -rf "$stage"

mkdir -p "$where"
python3 "$here/tools/mkdasd.py" "$where/lfs.ckd" "$work/out/lfs.ext4" --volser LFS131
rm -f "$work/out/lfs.ext4"
# norandmaps: no address space layout randomisation. Not for the kernel's sake -
# for a dynamically translating emulator, whose translated code carries the
# addresses it was made under, so that every process having its C library at
# an address of its own means translating the library again for every
# process. Hercules does not care either way. TERM=dumb is for systemd, see
# ch9-11.sh zipl_conf
python3 "$here/tools/mkins.py" "$here/build" lfs "$work/out/lfs-kernel.img" "" \
    "${CMDLINE:-dasd=0.0.0120 root=/dev/dasda1 ro rootwait norandmaps TERM=dumb}"
cp "$work/out/lfs-System.map" "$here/build/lfs.map"
echo "== $where/lfs.ckd and $here/build/lfs.ins"
