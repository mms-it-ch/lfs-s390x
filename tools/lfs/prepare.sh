#!/bin/bash
# LFS chapter 4, as root: $LFS with its limited directory layout, owned by the
# user who builds. The book makes a user "lfs" for that; here it is whoever
# runs the build, in an environment emptied by env -i (see ch5-6.sh).
#   prepare.sh USER
set -e
user=${1:?who builds}
export LFS=${LFS:-/mnt/lfs}
mkdir -pv $LFS/{etc,var,tools,sources} $LFS/usr/{bin,lib,sbin}
for i in bin lib sbin; do
    [ -e $LFS/$i ] || ln -sv usr/$i $LFS/$i
done
# s390x: the dynamic linker is /lib/ld64.so.1 and the libraries are told to
# live in lib (see gcc's t-linux64 below), so there is no lib64
chown -v $user $LFS/{usr{,/*},var,etc,tools,sources}
chmod -v a+wt $LFS/sources
