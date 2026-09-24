#!/bin/bash
# s390-tools 2.38.0, inside the chroot: what the book's GRUB chapter is on a
# PC, on this architecture - zipl, the boot loader that writes IPL records
# and a boot map onto a DASD, and the DASD tools beside it. Not the whole
# package, whose remaining tools want glib, fuse, curl, cryptsetup and more,
# but the seven directories that need only the C library and each other:
# libutil, libvtoc, libdasd, zipl, dasdfmt, fdasd, dasdview.
set -e
. /sources/scripts/common.sh

s390_tools() {
    # The boot loaders are compiled with -fexec-charset=IBM1047, which this
    # gcc has, and the tools link libutil.a and libvtoc.a out of the tree
    for d in libutil libvtoc libdasd zipl dasdfmt fdasd dasdview; do
        make -C $d HAVE_FUSE=0 HAVE_CURL=0 HAVE_OPENSSL=0 HAVE_CRYPTSETUP2=0 HAVE_JSONC=0 \
            HAVE_GLIB2=0 HAVE_LIBUDEV=0 HAVE_PFM=0 HAVE_ZLIB=0
    done
    for d in zipl dasdfmt fdasd dasdview; do
        make -C $d install DESTDIR=/ HAVE_FUSE=0 HAVE_CURL=0 HAVE_OPENSSL=0 \
            HAVE_CRYPTSETUP2=0 HAVE_JSONC=0 HAVE_GLIB2=0 HAVE_LIBUDEV=0 HAVE_PFM=0 HAVE_ZLIB=0
    done
    ls -la /usr/sbin/zipl /usr/sbin/dasdfmt /usr/sbin/fdasd /usr/sbin/dasdview
    zipl --version
}

step 10.4-s390-tools 's390-tools-*.tar.gz' s390_tools
echo "s390-tools are done"
