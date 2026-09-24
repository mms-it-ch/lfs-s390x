#!/bin/bash
# The sources of LFS 13.1 (systemd), as the book's own wget-list names them,
# checked against the book's md5sums. Also the book itself, in one page, which
# is what the build scripts are written from.
set -e
top=${LFS_WORK:-$HOME/lfs-s390x}
book=https://www.linuxfromscratch.org/lfs/downloads/stable-systemd
mkdir -p "$top/sources" "$top/book" && cd "$top/sources"

wget -nv -N $book/wget-list $book/md5sums
(cd "$top/book" && wget -nv -N -r -l1 -nd -A 'LFS-BOOK-*-NOCHUNKS.html' $book/ 2>&1 | tail -2) || true

# What is there and right is not fetched again
while read -r url; do
    file=${url##*/}
    sum=$(awk -v f="$file" '$2 == f { print $1 }' md5sums)
    if [ -f "$file" ] && [ -n "$sum" ] && [ "$(md5sum < "$file" | cut -d' ' -f1)" = "$sum" ]; then
        continue
    fi
    # ftpmirror.gnu.org sends the reader to a mirror of its choosing, and on
    # 19.09.2026 every third one was out of date or did not answer. The
    # releases are on ftp.gnu.org itself; the md5sums say whether it is the
    # same file
    url=${url/ftpmirror.gnu.org/ftp.gnu.org\/gnu}
    wget -nv --tries=2 --timeout=30 -O "$file" "$url" || { echo "FAILED: $url"; rm -f "$file"; }
done < wget-list

echo "== check"
md5sum -c md5sums 2>&1 | grep -v ': OK$' || echo "all $(wc -l < md5sums) files are right"
du -sh .
