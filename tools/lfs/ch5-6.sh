#!/bin/bash
# LFS 13.1 chapters 5 and 6 for s390x: the cross toolchain and the temporary
# tools, as the user who owns $LFS. The commands are the book's; what is not
# the book's is marked "s390x:". Run through env -i, as the book's
# .bash_profile does it:
#
#   env -i HOME=$HOME TERM=$TERM PATH=/usr/bin:/bin bash tools/lfs/ch5-6.sh
set -e
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

# What this project adds to the book's patches
cp "$here"/../../patches/*.patch $LFS/sources/

set +h
umask 022
PATH=$LFS/tools/bin:/usr/bin:/bin
export PATH CONFIG_SITE=$LFS/usr/share/config.site

# s390x: gcc calls the directory of the 64 bit libraries lib64 on this
# architecture as it does on x86_64, and the book wants lib. Same cure, other file
gcc_libdir() {
    sed -e 's|\.\./lib64|../lib|' -i.orig gcc/config/s390/t-linux64
}

gcc_prerequisites() {
    tar -xf $SRC/mpfr-4.2.2.tar.xz && mv mpfr-4.2.2 mpfr
    tar -xf $SRC/gmp-6.3.0.tar.xz && mv gmp-6.3.0 gmp
    tar -xf $SRC/mpc-1.4.1.tar.xz && mv mpc-1.4.1 mpc
}

# ------------------------------------------------------------- chapter 5

binutils_pass1() {
    mkdir build && cd build
    ../configure --prefix=$LFS/tools \
                 --with-sysroot=$LFS \
                 --target=$LFS_TGT   \
                 --disable-nls       \
                 --enable-gprofng=no \
                 --disable-werror    \
                 --enable-new-dtags  \
                 --enable-default-hash-style=gnu
    make
    make install
}

gcc_pass1() {
    gcc_prerequisites
    gcc_libdir
    mkdir build && cd build
    # s390x: --with-arch, for every program this compiler will ever build
    ../configure                  \
        --target=$LFS_TGT         \
        --prefix=$LFS/tools       \
        --with-glibc-version=2.44 \
        --with-sysroot=$LFS       \
        --with-newlib             \
        --without-headers         \
        --with-arch=$LFS_ARCH     \
        --enable-default-pie      \
        --enable-default-ssp      \
        --disable-fixincludes     \
        --disable-nls             \
        --disable-shared          \
        --disable-multilib        \
        --disable-threads         \
        --disable-libatomic       \
        --disable-libgomp         \
        --disable-libquadmath     \
        --disable-libssp          \
        --disable-libvtv          \
        --disable-libstdcxx       \
        --enable-languages=c,c++
    make
    make install
    cd ..
    cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
        $($LFS_TGT-gcc -print-file-name=include)/limits.h
}

linux_headers() {
    make mrproper
    # s390x: the host is not the target, so the architecture is named
    make ARCH=s390 headers
    find usr/include -type f ! -name '*.h' -delete
    cp -r usr/include $LFS/usr
}

glibc() {
    # s390x: none of the book's lib64 links - the dynamic linker is
    # /lib/ld64.so.1, and /lib is usr/lib
    patch -Np1 -i $SRC/glibc-fhs-1.patch
    patch -Np1 -i $SRC/glibc-2.44-upstream_fixes-1.patch
    mkdir build && cd build
    echo "rootsbindir=/usr/sbin" > configparms
    ../configure                             \
          --prefix=/usr                      \
          --host=$LFS_TGT                    \
          --build=$(../scripts/config.guess) \
          --disable-nscd                     \
          libc_cv_slibdir=/usr/lib           \
          --enable-kernel=5.10
    make
    make DESTDIR=$LFS install
    sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd

    # The book's sanity checks, with their answers in the log
    echo 'int main(){}' | $LFS_TGT-gcc -x c - -v -Wl,--verbose &> dummy.log
    $LFS_TGT-readelf -l a.out | grep ': /lib'
    grep -E -o "$LFS/lib.*/S?crt[1in].*succeeded" dummy.log
    grep -B3 "^ $LFS/usr/include" dummy.log
    grep 'SEARCH.*/usr/lib' dummy.log | sed 's|; |\n|g'
    grep "/lib.*/libc.so.6 " dummy.log
    grep found dummy.log
    # s390x: and it is the dynamic linker of this architecture that is asked for
    $LFS_TGT-readelf -l a.out | grep -q '/lib/ld64.so.1'
    test -e $LFS/lib/ld64.so.1
}

libstdcxx() {
    mkdir build && cd build
    ../libstdc++-v3/configure      \
        --host=$LFS_TGT            \
        --build=$(../config.guess) \
        CXX=$LFS_TGT-gcc           \
        --prefix=/usr              \
        --disable-multilib         \
        --disable-nls              \
        --disable-libstdcxx-pch    \
        --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/16.2.0
    make
    make DESTDIR=$LFS install
    rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la
}

# ------------------------------------------------------------- chapter 6

m4() {
    {
        echo ac_cv_func_posix_spawn_file_actions_addchdir=yes
        echo ac_cv_func_posix_spawn_file_actions_addfchdir=yes
    } > $LFS/usr/share/config.site
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make
    make DESTDIR=$LFS install
}

ncurses() {
    mkdir build
    pushd build
      ../configure --prefix=$LFS/tools AWK=gawk
      make -C include
      make -C progs tic
      install progs/tic $LFS/tools/bin
    popd
    ./configure --prefix=/usr                \
                --host=$LFS_TGT              \
                --build=$(./config.guess)    \
                --mandir=/usr/share/man      \
                --with-manpage-format=normal \
                --with-shared                \
                --without-normal             \
                --with-cxx-shared            \
                --without-debug              \
                --without-ada                \
                --disable-stripping          \
                AWK=gawk
    make
    make DESTDIR=$LFS install
    ln -sv libncursesw.so $LFS/usr/lib/libncurses.so
    sed -e 's/^#if.*XOPEN.*$/#if 1/' -i $LFS/usr/include/curses.h
}

bash_() {
    ./configure --prefix=/usr                      \
                --build=$(sh support/config.guess) \
                --host=$LFS_TGT                    \
                --without-bash-malloc              \
                --docdir=/usr/share/doc/bash-5.3
    make
    make DESTDIR=$LFS install
    ln -sv bash $LFS/bin/sh
}

coreutils() {
    ./configure --prefix=/usr                     \
                --host=$LFS_TGT                   \
                --build=$(build-aux/config.guess) \
                --enable-install-program=hostname
    make
    make DESTDIR=$LFS install
    mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
    mkdir -pv $LFS/usr/share/man/man8
    mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
    sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8
}

diffutils() {
    ./configure --prefix=/usr --host=$LFS_TGT gl_cv_func_strcasecmp_works=yes \
                --build=$(./build-aux/config.guess)
    make
    make DESTDIR=$LFS install
}

file_() {
    mkdir build
    pushd build
      ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
      make
    popd
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
    make FILE_COMPILE=$(pwd)/build/src/file
    make DESTDIR=$LFS install
    rm -v $LFS/usr/lib/libmagic.la
}

findutils() {
    ./configure --prefix=/usr --localstatedir=/var/lib/locate \
                --host=$LFS_TGT --build=$(build-aux/config.guess)
    make
    make DESTDIR=$LFS install
}

gawk_() {
    # not the book's: see patches/, and "What S2 found out" in the README
    patch -Np1 -i $SRC/gawk-5.4.1-unassigned_element-1.patch
    sed -i 's/extras//' Makefile.in
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
    make
    make DESTDIR=$LFS install
}

# Those that are configure, make, make install and nothing else
plain() {
    local guess=build-aux/config.guess
    [ -f $guess ] || guess=./config.guess
    ./configure --prefix=/usr --host=$LFS_TGT --build=$($guess)
    make
    make DESTDIR=$LFS install
}

gzip_() {
    ./configure --prefix=/usr --host=$LFS_TGT
    make
    make DESTDIR=$LFS install
}

xz_() {
    ./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess) \
                --disable-static --docdir=/usr/share/doc/xz-5.8.3
    make
    make DESTDIR=$LFS install
    rm -v $LFS/usr/lib/liblzma.la
}

binutils_pass2() {
    sed '6031s/$add_dir//' -i ltmain.sh
    mkdir build && cd build
    ../configure                   \
        --prefix=/usr              \
        --build=$(../config.guess) \
        --host=$LFS_TGT            \
        --disable-nls              \
        --enable-shared            \
        --enable-gprofng=no        \
        --disable-werror           \
        --enable-64-bit-bfd        \
        --enable-new-dtags         \
        --enable-default-hash-style=gnu
    make
    make DESTDIR=$LFS install
    rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
}

gcc_pass2() {
    gcc_prerequisites
    gcc_libdir
    mkdir build && cd build
    ../configure                   \
        --build=$(../config.guess) \
        --host=$LFS_TGT            \
        --target=$LFS_TGT          \
        --prefix=/usr              \
        --with-build-sysroot=$LFS  \
        --with-arch=$LFS_ARCH      \
        --enable-default-pie       \
        --enable-default-ssp       \
        --disable-fixincludes      \
        --disable-nls              \
        --disable-multilib         \
        --disable-libatomic        \
        --disable-libgomp          \
        --disable-libquadmath      \
        --disable-libsanitizer     \
        --disable-libssp           \
        --disable-libvtv           \
        --enable-languages=c,c++   \
        CXX_FOR_TARGET="$LFS_TGT-gcc -nostdinc++" \
        LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc \
        target_configargs=gcc_cv_target_thread_file=posix
    make
    make DESTDIR=$LFS install
    ln -sv gcc $LFS/usr/bin/cc
}

step 5.2-binutils-pass1  'binutils-*.tar.xz'  binutils_pass1
step 5.3-gcc-pass1       'gcc-*.tar.xz'       gcc_pass1
step 5.4-linux-headers   'linux-*.tar.xz'     linux_headers
step 5.5-glibc           'glibc-*.tar.xz'     glibc
step 5.6-libstdcxx       'gcc-*.tar.xz'       libstdcxx
step 6.2-m4              'm4-*.tar.xz'        m4
step 6.3-ncurses         'ncurses-*.tar.gz'   ncurses
step 6.4-bash            'bash-*.tar.gz'      bash_
step 6.5-coreutils       'coreutils-*.tar.xz' coreutils
step 6.6-diffutils       'diffutils-*.tar.xz' diffutils
step 6.7-file            'file-*.tar.gz'      file_
step 6.8-findutils       'findutils-*.tar.xz' findutils
step 6.9-gawk            'gawk-*.tar.xz'      gawk_
step 6.10-grep           'grep-*.tar.xz'      plain
step 6.11-gzip           'gzip-*.tar.xz'      gzip_
step 6.12-make           'make-*.tar.gz'      plain
step 6.13-patch          'patch-*.tar.xz'     plain
step 6.14-sed            'sed-*.tar.xz'       plain
step 6.15-tar            'tar-*.tar.xz'       plain
step 6.16-xz             'xz-*.tar.xz'        xz_
step 6.17-binutils-pass2 'binutils-*.tar.xz'  binutils_pass2
step 6.18-gcc-pass2      'gcc-*.tar.xz'       gcc_pass2
echo "chapters 5 and 6 are done"
