#!/bin/bash
# As root: waits for chapters 5 and 6 to be done and then runs chapters 7, 8
# and 9 to 11 in the chroot, one after the other - a night's work for the machine, and
# nothing for anybody to watch. What it says goes to $LFS/sources/logs/rest.log;
# which package it is at is the newest file in $LFS/sources/stamps.
#
#   rest.sh BUILDER
set -e
builder=${1:?who builds chapters 5 and 6}
here=$(cd "$(dirname "$0")" && pwd)
export LFS=${LFS:-/mnt/lfs}
mkdir -p $LFS/sources/logs
exec >> $LFS/sources/logs/rest.log 2>&1

# The disk this all lives on is a file on drive C: that grows as it is written
# to, and df in here knows nothing of how much room C: has left. On 19.09.2026
# it had none: the file system answered every call with an I/O error and took
# the distribution with it. So somebody watches, and stops the build while
# there is still room to stop in.
watch_the_host() {
    while sleep 60; do
        free=$(df --output=avail -BM /mnt/c 2>/dev/null | tail -1 | tr -dc 0-9)
        if [ -n "$free" ] && [ "$free" -lt ${LFS_HOST_MIN_MB:-4096} ]; then
            echo "== $(date '+%F %T') only $free MB left on drive C: - stopping the build"
            pkill -f 'scripts/ch[78].sh'; pkill -f ch5-6.sh; pkill make; pkill ninja
            kill $$
            exit 1
        fi
    done
}
watch_the_host &
trap 'kill %1 2>/dev/null' EXIT

echo "== $(date '+%F %T') waiting for chapters 5 and 6"
while [ ! -f $LFS/sources/stamps/6.18-gcc-pass2 ]; do
    if ! pgrep -f ch5-6.sh > /dev/null; then
        # It ended; with or without the last stamp?
        sleep 5
        [ -f $LFS/sources/stamps/6.18-gcc-pass2 ] && break
        echo "== $(date '+%F %T') chapters 5 and 6 ended without finishing - nothing done"
        exit 1
    fi
    sleep 30
done
sleep 10

for chapter in ch7.sh ch8.sh ch9-11.sh; do
    echo "== $(date '+%F %T') $chapter"
    bash "$here/chroot.sh" "$builder" $chapter
done
echo "== $(date '+%F %T') chapters 7 to 11 are done"
