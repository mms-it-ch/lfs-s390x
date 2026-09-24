#!/bin/bash
# The kernel of LFS 13.1 for s390x, cross-compiled: tinyconfig with
# config/NAME.config laid over it. Leaves image, System.map and vmlinux in
# $LFS_WORK/out/NAME.
set -e
name=${1:-stage0}
here=$(cd "$(dirname "$0")/.." && pwd)
top=${LFS_WORK:-$HOME/lfs-s390x}
src=$top/build/linux-7.1.8
obj=$top/build/linux-$name
out=$top/out/$name
mk="make -C $src O=$obj ARCH=s390 CROSS_COMPILE=s390x-linux-gnu- -j$(nproc)"

mkdir -p "$obj" "$out"
if [ ! -f "$obj/.config" ] || [ "$here/config/$name.config" -nt "$obj/.config" ]; then
    $mk tinyconfig >/dev/null
    (cd "$obj" && ARCH=s390 "$src/scripts/kconfig/merge_config.sh" -m -O "$obj" .config "$here/config/$name.config" >/dev/null)
    $mk olddefconfig >/dev/null
    # What the fragment asked for and did not get
    while read -r line; do
        case "$line" in
            CONFIG_*=*) grep -qx "$line" "$obj/.config" || echo "NOT TAKEN: $line" ;;
        esac
    done < "$here/config/$name.config"
fi
$mk bzImage 2>&1 | tail -15
cp "$obj/arch/s390/boot/bzImage" "$out/kernel.img"
cp "$obj/System.map" "$obj/vmlinux" "$obj/.config" "$out/"
cp "$obj/arch/s390/boot/vmlinux" "$out/vmlinux.boot" 2>/dev/null || true
ls -la "$out"
