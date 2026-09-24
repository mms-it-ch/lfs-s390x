#!/bin/bash
# The source of s390-tools, for zipl (S4): the boot loader that puts IPL
# records on a DASD, and dasdfmt, fdasd, chccwdev beside it. From IBM's
# repository on GitHub, the release named here, checked against the hash of
# the tarball as GitHub serves it (recorded on first download).
set -e
top=${LFS_WORK:-$HOME/lfs-s390x}
ver=${1:-2.38.0}
mkdir -p "$top/sources" && cd "$top/sources"
f=s390-tools-$ver.tar.gz
[ -f $f ] || wget -nv -O $f https://github.com/ibm-s390-linux/s390-tools/archive/refs/tags/v$ver.tar.gz
sha256sum $f | tee $f.sha256
tar -tzf $f | head -3
ls -la $f
