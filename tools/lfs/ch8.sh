#!/bin/bash
# LFS 13.1 chapter 8, inside the chroot (tools/lfs/chroot.sh runs it): the
# system itself, every package compiled by the compiler of chapter 6 and then
# by its own, all of it under qemu-s390x.
#
# Drafted by tools/lfs/draft-chapter.py out of the book, so the commands are
# the book's to the letter; what was changed afterwards is marked where it is:
#   "s390x:"       the architecture asks for something else
#   "unattended:"  the book asks the reader, and there is no reader
#   "the book's test:"  kept as comment. Under qemu-user the test suites are
#                  days, and what they would find is how well qemu emulates
set -e
. /sources/scripts/common.sh

# 8.3. Man-pages-6.18
p_man_pages() {
    rm -v man3/crypt*
    make -R GIT=false prefix=/usr install
}

# 8.4. Iana-Etc-20260805
p_iana_etc() {
    cp -v services protocols /etc
}

# 8.5. Glibc-2.44
p_glibc() {
    patch -Np1 -i ../glibc-fhs-1.patch
    patch -Np1 -i ../glibc-2.44-upstream_fixes-1.patch
    mkdir -v build
    cd       build
    ../configure --prefix=/usr                   \
                 --disable-werror                \
                 --disable-nscd                  \
                 libc_cv_slibdir=/usr/lib        \
                 --enable-stack-protector=strong \
                 --enable-kernel=5.10
    make
    # the book's test:
    #   make check
    # the book's test:
    #   grep "Timed out" $(find -name \*.out)
    touch /etc/ld.so.conf
    sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
    # (what the book says here about nscd, DESTDIR=$PWD/dest and include-fixed
    # is for upgrading the Glibc of a running system, which this is not)
    make install
    sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
    localedef -i C -f UTF-8 C.UTF-8
    localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
    localedef -i de_DE -f ISO-8859-1 de_DE
    localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
    localedef -i de_DE -f UTF-8 de_DE.UTF-8
    localedef -i el_GR -f ISO-8859-7 el_GR
    localedef -i en_GB -f ISO-8859-1 en_GB
    localedef -i en_GB -f UTF-8 en_GB.UTF-8
    localedef -i en_HK -f ISO-8859-1 en_HK
    localedef -i en_PH -f ISO-8859-1 en_PH
    localedef -i en_US -f ISO-8859-1 en_US
    localedef -i en_US -f UTF-8 en_US.UTF-8
    localedef -i es_ES -f ISO-8859-15 es_ES@euro
    localedef -i es_MX -f ISO-8859-1 es_MX
    localedef -i fa_IR -f UTF-8 fa_IR
    localedef -i fr_FR -f ISO-8859-1 fr_FR
    localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
    localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
    localedef -i is_IS -f ISO-8859-1 is_IS
    localedef -i is_IS -f UTF-8 is_IS.UTF-8
    localedef -i it_IT -f ISO-8859-1 it_IT
    localedef -i it_IT -f ISO-8859-15 it_IT@euro
    localedef -i it_IT -f UTF-8 it_IT.UTF-8
    localedef -i ja_JP -f EUC-JP ja_JP
    localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
    localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro
    localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
    localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
    localedef -i se_NO -f UTF-8 se_NO.UTF-8
    localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
    localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
    localedef -i zh_CN -f GB18030 zh_CN.GB18030
    localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
    localedef -i zh_TW -f UTF-8 zh_TW.UTF-8
    # (the book's alternative, make localedata/install-locales, is every
    # locale there is - hours under qemu for something nobody will read)
    cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files systemd
group: files systemd
shadow: files systemd

hosts: mymachines resolve [!UNAVAIL=return] files myhostname dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF
    tar -xf ../../tzdata2026c.tar.gz

    ZONEINFO=/usr/share/zoneinfo
    mkdir -pv $ZONEINFO/{posix,right}

    for tz in etcetera southamerica northamerica europe africa antarctica  \
              asia australasia backward; do
        zic -L /dev/null   -d $ZONEINFO       ${tz}
        zic -L /dev/null   -d $ZONEINFO/posix ${tz}
        zic -L leapseconds -d $ZONEINFO/right ${tz}
    done

    cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
    zic -d $ZONEINFO -p America/New_York
    unset ZONEINFO tz
    # unattended: tzselect asks; the answer is where this machine stands
    ln -sfv /usr/share/zoneinfo/Europe/Berlin /etc/localtime
    cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF
    cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
    mkdir -pv /etc/ld.so.conf.d
}

# 8.6. Zlib-1.3.2
p_zlib() {
    ./configure --prefix=/usr
    # s390x: configure works out VGFMAFLAG and does not write it into the
    # Makefile - see chapter 7
    make VGFMAFLAG="-mzarch -march=z13"
    # the book's test:
    #   make check
    make VGFMAFLAG="-mzarch -march=z13" install
    rm -fv /usr/lib/libz.a
}

# 8.7. Bzip2-1.0.8
p_bzip2() {
    patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
    sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
    sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
    make -f Makefile-libbz2_so
    make clean
    make
    make PREFIX=/usr install
    cp -av libbz2.so.* /usr/lib
    ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so
    ln -sfv libbz2.so.1.0.8 /usr/lib/libbz2.so.1
    cp -v bzip2-shared /usr/bin/bzip2
    for i in /usr/bin/{bzcat,bunzip2}; do
      ln -sfv bzip2 $i
    done
    rm -fv /usr/lib/libbz2.a
}

# 8.8. Xz-5.8.3
p_xz() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/xz-5.8.3
    make
    # the book's test:
    #   make check
    make install
}

# 8.9. Lz4-1.10.0
p_lz4() {
    make BUILD_STATIC=no PREFIX=/usr
    # the book's test:
    #   make -j1 check
    make BUILD_STATIC=no PREFIX=/usr install
}

# 8.10. Zstd-1.5.7
p_zstd() {
    make prefix=/usr
    # the book's test:
    #   make check
    make prefix=/usr install
    rm -v /usr/lib/libzstd.a
}

# 8.11. File-5.48
p_file() {
    ./configure --prefix=/usr
    make
    # the book's test:
    #   make check
    make install
}

# 8.12. Readline-8.3
p_readline() {
    sed -i '/MV.*old/d' Makefile.in
    sed -i '/{OLDSUFF}/c:' support/shlib-install
    sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf
    sed -e '270a\
         else\
           chars_avail = 1;'      \
        -e '288i\   result = -1;' \
        -i.orig input.c
    ./configure --prefix=/usr    \
                --disable-static \
                --with-curses    \
                --docdir=/usr/share/doc/readline-8.3
    make SHLIB_LIBS="-lncursesw"
    make install
    install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.3
}

# 8.13. Pcre2-10.47
p_pcre2() {
    ./configure --prefix=/usr                       \
                --docdir=/usr/share/doc/pcre2-10.47 \
                --enable-unicode                    \
                --enable-jit                        \
                --enable-pcre2-16                   \
                --enable-pcre2-32                   \
                --enable-pcre2grep-libz             \
                --enable-pcre2grep-libbz2           \
                --enable-pcre2test-libreadline      \
                --disable-static
    make
    # the book's test:
    #   make check
    make install
}

# 8.14. M4-1.4.21
p_m4() {
    ./configure --prefix=/usr
    make
    # the book's test:
    #   make check
    make install
}

# 8.15. Bc-7.0.3
p_bc() {
    CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r
    make
    # the book's test:
    #   make test
    make install
}

# 8.16. Flex-2.6.4
p_flex() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/flex-2.6.4
    make
    # the book's test:
    #   make check
    make install
    ln -sv flex   /usr/bin/lex
    ln -sv flex.1 /usr/share/man/man1/lex.1
}

# 8.17. Tcl-8.6.18
p_tcl() {
    SRCDIR=$(pwd)
    cd unix
    ./configure --prefix=/usr           \
                --mandir=/usr/share/man \
                --disable-rpath
    make

    sed -e "s|$SRCDIR/unix|/usr/lib|" \
        -e "s|$SRCDIR|/usr/include|"  \
        -i tclConfig.sh

    sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.13|/usr/lib/tdbc1.1.13|" \
        -e "s|$SRCDIR/pkgs/tdbc1.1.13/generic|/usr/include|"     \
        -e "s|$SRCDIR/pkgs/tdbc1.1.13/library|/usr/lib/tcl8.6|"  \
        -e "s|$SRCDIR/pkgs/tdbc1.1.13|/usr/include|"             \
        -i pkgs/tdbc1.1.13/tdbcConfig.sh

    sed -e "s|$SRCDIR/unix/pkgs/itcl4.3.7|/usr/lib/itcl4.3.7|" \
        -e "s|$SRCDIR/pkgs/itcl4.3.7/generic|/usr/include|"    \
        -e "s|$SRCDIR/pkgs/itcl4.3.7|/usr/include|"            \
        -i pkgs/itcl4.3.7/itclConfig.sh

    unset SRCDIR
    # the book's test:
    #   LC_ALL=C.UTF-8 make test
    make install 
    chmod 644 /usr/lib/libtclstub8.6.a
    chmod -v u+w /usr/lib/libtcl8.6.so
    make install-private-headers
    ln -sfv tclsh8.6 /usr/bin/tclsh
    mv -v /usr/share/man/man3/{Thread,Tcl_Thread}.3
    cd ..
    tar -xf ../tcl8.6.18-html.tar.gz --strip-components=1
    mkdir -v -p /usr/share/doc/tcl-8.6.18
    cp -v -r  ./html/* /usr/share/doc/tcl-8.6.18
}

# 8.18. Expect-5.45.4
p_expect() {
    # the book's test:
    #   python3 -c 'from pty import spawn; spawn(["echo", "ok"])'
    patch -Np1 -i ../expect-5.45.4-gcc15-1.patch
    ./configure --prefix=/usr           \
                --with-tcl=/usr/lib     \
                --enable-shared         \
                --disable-rpath         \
                --mandir=/usr/share/man \
                --with-tclinclude=/usr/include
    make
    # the book's test:
    #   make test
    make install
    ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
}

# 8.19. DejaGNU-1.6.3
p_dejagnu() {
    mkdir -v build
    cd       build
    ../configure --prefix=/usr
    makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
    makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi
    # the book's test:
    #   make check
    make install
    install -v -dm755  /usr/share/doc/dejagnu-1.6.3
    install -v -m644   doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3
}

# 8.20. Ninja-1.13.2
p_ninja() {
    sed -i '/int Guess/a \
      int   j = 0;\
      char* jobs = getenv( "NINJAJOBS" );\
      if ( jobs != NULL ) j = atoi( jobs );\
      if ( j > 0 ) return j;\
    ' src/ninja.cc
    python3 configure.py --bootstrap --verbose
    install -vm755 ninja /usr/bin/
    install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
    install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
}

# 8.21. Pkgconf-3.0.5
p_pkgconf() {
    tar -xf ../meson-1.12.0.tar.gz
    mkdir build
    cd    build

    python3 ../meson-1.12.0/meson.py setup --prefix=/usr --buildtype=release ..
    ninja
    # the book's test:
    #   ninja test
    ninja install
    mv /usr/share/doc/pkgconf{,-3.0.5}
    ln -sv pkgconf   /usr/bin/pkg-config
    ln -sv pkgconf.1 /usr/share/man/man1/pkg-config.1
}

# 8.22. Binutils-2.47
p_binutils() {
    mkdir -v build
    cd       build
    ../configure --prefix=/usr       \
                 --sysconfdir=/etc   \
                 --enable-ld=default \
                 --enable-plugins    \
                 --enable-shared     \
                 --disable-werror    \
                 --enable-64-bit-bfd \
                 --enable-new-dtags  \
                 --with-system-zlib  \
                 --with-lib-path=/usr/lib \
                 --enable-default-hash-style=gnu
    make tooldir=/usr
    # the book's test:
    #   make -k check
    # the book's test:
    #   grep '^FAIL:' $(find -name '*.log')
    make tooldir=/usr install
    rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a \
            /usr/share/doc/gprofng/
}

# 8.23. GMP-6.3.0
p_gmp() {
    # (the book's ABI=32 line is for a 32 bit x86)
    # s390x: the book's advice for a library that is to run on another
    # processor than the one it was built on - which here is qemu's idea of one
    cp -v configfsf.guess config.guess
    cp -v configfsf.sub   config.sub
    sed -i '/long long t1;/,+1s/()/(...)/' configure
    ./configure --prefix=/usr    \
                --enable-cxx     \
                --disable-static \
                --docdir=/usr/share/doc/gmp-6.3.0
    make
    make html
    # the book's test:
    #   make check
    # the book's test:
    #   cat $(find -name '*.log') | grep -c ^PASS
    make install
    make install-html
}

# 8.24. MPFR-4.2.2
p_mpfr() {
    ./configure --prefix=/usr        \
                --disable-static     \
                --enable-thread-safe \
                --docdir=/usr/share/doc/mpfr-4.2.2
    make
    make html
    # the book's test:
    #   make check
    make install
    make install-html
}

# 8.25. MPC-1.4.1
p_mpc() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/mpc-1.4.1
    make
    make html
    # the book's test:
    #   make check
    make install
    make install-html
}

# 8.26. Attr-2.6.0
p_attr() {
    ./configure --prefix=/usr     \
                --disable-static  \
                --sysconfdir=/etc \
                --docdir=/usr/share/doc/attr-2.6.0
    make
    # the book's test:
    #   make check
    make install
}

# 8.27. Acl-2.4.0
p_acl() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/acl-2.4.0
    make
    # the book's test:
    #   make check
    make install
}

# 8.28. Libcap-2.78
p_libcap() {
    sed -i '/install -m.*STA/d' libcap/Makefile
    make prefix=/usr lib=lib
    # the book's test:
    #   make test
    make prefix=/usr lib=lib install
}

# 8.29. Libxcrypt-4.5.2
p_libxcrypt() {
    sed -i '/strchr/s/const//' lib/crypt-{sm3,gost}-yescrypt.c
    ./configure --prefix=/usr                \
                --enable-hashes=strong,glibc \
                --enable-obsolete-api=no     \
                --disable-static             \
                --disable-failure-tokens
    make
    # the book's test:
    #   make check
    make install
    make distclean
    ./configure --prefix=/usr                \
                --enable-hashes=strong,glibc \
                --enable-obsolete-api=glibc  \
                --disable-static             \
                --disable-failure-tokens
    make
    cp -av --remove-destination .libs/libcrypt.so.1* /usr/lib
}

# 8.30. Shadow-4.20.2
p_shadow() {
    find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
    find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
    sed -e 's:#ENCRYPT_METHOD SHA512:ENCRYPT_METHOD YESCRYPT:' \
        -e 's:/var/spool/mail:/var/mail:'                      \
        -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                     \
        -i etc/login.defs
    touch /usr/bin/passwd
    ./configure --sysconfdir=/etc   \
                --disable-static    \
                --with-{b,yes}crypt \
                --without-libbsd    \
                --disable-logind    \
                --with-group-name-max-length=32
    make
    make exec_prefix=/usr install
    make -C man install-man
    pwconv
    grpconv
    mkdir -p /etc/default
    useradd -D --gid 999
    sed -i '/MAIL/s/yes/no/' /etc/default/useradd
    touch /etc/sub{u,g}id
    # unattended: passwd asks twice. A machine whose only terminal is the
    # operator's console gets a password that is written down here
    echo 'root:lfs' | chpasswd
}

# 8.31. Gawk-5.4.1
p_gawk() {
    # not the book's: see patches/, and "What S2 found out" in the README
    patch -Np1 -i ../gawk-5.4.1-unassigned_element-1.patch
    sed -i 's/extras//' Makefile.in
    ./configure --prefix=/usr
    make
    # the book's test:
    #   chown -R tester .
    #   su tester -c "PATH=$PATH make check"
    rm -f /usr/bin/gawk-5.4.1
    make install
    ln -sv gawk.1 /usr/share/man/man1/awk.1
    install -vDm644 doc/{awkforai.txt,*.{eps,pdf,jpg}} -t /usr/share/doc/gawk-5.4.1
}

# 8.32. GCC-16.2.0
p_gcc() {
    # s390x: the book's cure for lib64 on x86_64, applied to this
    # architecture's file of the same name - and --with-arch, as in chapter 5
    sed -e 's|\.\./lib64|../lib|' -i.orig gcc/config/s390/t-linux64
    mkdir -v build
    cd       build
    ../configure --prefix=/usr            \
                 LD=ld                    \
                 --with-arch=$LFS_ARCH    \
                 --enable-languages=c,c++ \
                 --enable-default-pie     \
                 --enable-default-ssp     \
                 --enable-host-pie        \
                 --enable-targets=all     \
                 --disable-multilib       \
                 --disable-bootstrap      \
                 --disable-fixincludes    \
                 --with-system-zlib
    make
    # the book's test:
    #   ulimit -s -H unlimited
    # the book's test:
    #   chown -R tester .
    #   su tester -c "PATH=$PATH make -k check"
    # the book's test:
    #   ../contrib/test_summary -t
    make install
    chown -v -R root:root $(gcc -print-file-name=include){,-fixed}
    ln -svr /usr/bin/cpp /usr/lib
    ln -sv gcc.1 /usr/share/man/man1/cc.1
    ln -sfvr $(gcc -print-prog-name=liblto_plugin.so) /usr/lib/bfd-plugins/
    echo 'int main(){}' | cc -x c - -v -Wl,--verbose &> dummy.log
    readelf -l a.out | grep ': /lib'
    grep -E -o '/usr/lib.*/S?crt[1in].*succeeded' dummy.log
    grep -B4 '^ /usr/include' dummy.log
    grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
    grep "/lib.*/libc.so.6 " dummy.log
    grep found dummy.log
    # s390x: the dynamic linker of this architecture
    readelf -l a.out | grep -q '/lib/ld64.so.1'
    rm -v a.out dummy.log
    mkdir -pv /usr/share/gdb/auto-load/usr/lib
    mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
}

# 8.33. Ncurses-6.6
p_ncurses() {
    ./configure --prefix=/usr           \
                --mandir=/usr/share/man \
                --with-shared           \
                --without-debug         \
                --without-normal        \
                --with-cxx-shared       \
                --enable-pc-files       \
                --with-pkg-config-libdir=/usr/lib/pkgconfig
    make
    make DESTDIR=$PWD/dest install
    sed -e 's/^#if.*XOPEN.*$/#if 1/' \
        -i dest/usr/include/curses.h
    cp --remove-destination -av dest/* /
    for lib in ncurses form panel menu ; do
        ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
        ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
    done
    ln -sfv libncursesw.so /usr/lib/libcurses.so
    cp -v -R doc -T /usr/share/doc/ncurses-6.6
    make distclean
    ./configure --prefix=/usr    \
                --with-shared    \
                --without-normal \
                --without-debug  \
                --without-cxx-binding \
                --with-abi-version=5
    make sources libs
    cp -av lib/lib*.so.5* /usr/lib
}

# 8.34. Sed-4.10
p_sed() {
    ./configure --prefix=/usr
    make
    make html
    # the book's test:
    #   chown -R tester .
    #   su tester -c "PATH=$PATH make check"
    make install
    install -vDm644 doc/sed.html -t /usr/share/doc/sed-4.10
}

# 8.35. Psmisc-23.7
p_psmisc() {
    ./configure --prefix=/usr
    make
    # the book's test:
    #   make check
    make install
}

# 8.36. Gettext-1.0
p_gettext() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/gettext-1.0
    make
    # the book's test:
    #   make check
    make install
    chmod -v 0755 /usr/lib/preloadable_libintl.so
}

# 8.37. Bison-3.8.2
p_bison() {
    ./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
    make
    # the book's test:
    #   make check
    make install
}

# 8.38. Grep-3.12
p_grep() {
    sed -i "s/echo/#echo/" src/egrep.sh
    ./configure --prefix=/usr
    make
    # the book's test:
    #   make check
    make install
}

# 8.39. Bash-5.3
p_bash() {
    ./configure --prefix=/usr             \
                --without-bash-malloc     \
                --with-installed-readline \
                --docdir=/usr/share/doc/bash-5.3
    make
    # the book's test:
    #   chown -R tester .
    # the book's test:
    #   LC_ALL=C.UTF-8 su -s /usr/bin/expect tester << "EOF"
    #   set timeout -1
    #   spawn make tests
    #   expect eof
    #   lassign [wait] _ _ _ value
    #   exit $value
    #   EOF
    make install
    # unattended: the book starts the new bash here, exec /usr/bin/bash --login.
    # Every step of this script starts a shell of its own, so the next one has it
}

# 8.40. Libtool-2.6.2
p_libtool() {
    ./configure --prefix=/usr
    make
    # the book's test:
    #   make check
    make install
    rm -fv /usr/lib/libltdl.a
}

# 8.41. GDBM-1.26
p_gdbm() {
    ./configure --prefix=/usr    \
                --disable-static \
                --enable-libgdbm-compat
    make
    # the book's test:
    #   make check
    make install
}

# 8.42. Gperf-3.3
p_gperf() {
    ./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3
    make
    # the book's test:
    #   make check
    make install
}

# 8.43. Expat-2.8.3
p_expat() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/expat-2.8.3
    make
    # the book's test:
    #   make check
    make install
    install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.8.3
}

# 8.44. Inetutils-2.8
p_inetutils() {
    sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c
    ./configure --prefix=/usr        \
                --bindir=/usr/bin    \
                --localstatedir=/var \
                --disable-logger     \
                --disable-whois      \
                --disable-rcp        \
                --disable-rexec      \
                --disable-rlogin     \
                --disable-rsh        \
                --disable-servers
    make
    # the book's test:
    #   make check
    make install
    mv -v /usr/{,s}bin/ifconfig
}

# 8.45. Less-704
p_less() {
    ./configure --prefix=/usr --sysconfdir=/etc
    make
    # the book's test:
    #   make check
    make install
}

# 8.46. Perl-5.44.0
p_perl() {
    export BUILD_ZLIB=False
    export BUILD_BZIP2=0
    sh Configure -des                                          \
                 -D prefix=/usr                                \
                 -D vendorprefix=/usr                          \
                 -D privlib=/usr/lib/perl5/5.44/core_perl      \
                 -D archlib=/usr/lib/perl5/5.44/core_perl      \
                 -D sitelib=/usr/lib/perl5/5.44/site_perl      \
                 -D sitearch=/usr/lib/perl5/5.44/site_perl     \
                 -D vendorlib=/usr/lib/perl5/5.44/vendor_perl  \
                 -D vendorarch=/usr/lib/perl5/5.44/vendor_perl \
                 -D man1dir=/usr/share/man/man1                \
                 -D man3dir=/usr/share/man/man3                \
                 -D pager="/usr/bin/less -isR"                 \
                 -D useshrplib                                 \
                 -D usethreads
    make
    # the book's test:
    #   TEST_JOBS=$(nproc) make test_harness
    make install
    unset BUILD_ZLIB BUILD_BZIP2
}

# 8.47. Autoconf-2.73
p_autoconf() {
    ./configure --prefix=/usr
    make
    # the book's test:
    #   make check
    make install
}

# 8.48. Automake-1.18.1
p_automake() {
    ./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.18.1
    make
    # the book's test:
    #   make -j$(($(nproc)>4?$(nproc):4)) check
    make install
}

# 8.49. OpenSSL-4.0.1
p_openssl() {
    ./config --prefix=/usr         \
             --openssldir=/etc/ssl \
             --libdir=lib          \
             shared                \
             zlib-dynamic
    make
    # the book's test:
    #   make test
    make INSTALL_LIBS= MANSUFFIX=ssl install
    mv -v /usr/share/doc/openssl /usr/share/doc/openssl-4.0.1
    cp -vfr doc/* /usr/share/doc/openssl-4.0.1
}

# 8.50. Libelf from Elfutils-0.195
p_libelf_from_elfutils() {
    ./configure --prefix=/usr        \
                --disable-debuginfod \
                --enable-libdebuginfod=dummy
    make -C lib
    make -C libelf
    # the book's test:
    #   make -k check
    make -C libelf install
    install -vm644 config/libelf.pc /usr/lib/pkgconfig
    rm /usr/lib/libelf.a
}

# 8.51. Libffi-3.8.0
p_libffi() {
    ./configure --prefix=/usr    \
                --disable-static \
                --with-gcc-arch=$LFS_ARCH
    # s390x: "native" is whatever qemu says it is; the book itself says to name
    # the processor when the system is to run on another one
    make
    # the book's test:
    #   make check
    make install
}

# 8.52. Sqlite-3530400
p_sqlite() {
    python3 -m zipfile -e ../sqlite-doc-3530400.zip .
    ./configure --prefix=/usr     \
                --disable-static  \
                --enable-fts{4,5} \
                CPPFLAGS="-D SQLITE_ENABLE_COLUMN_METADATA=1 \
                          -D SQLITE_ENABLE_UNLOCK_NOTIFY=1   \
                          -D SQLITE_ENABLE_DBSTAT_VTAB=1     \
                          -D SQLITE_SECURE_DELETE=1"
    make LDFLAGS.rpath=""
    make install
    cp -v -R sqlite-doc-3530400 -T /usr/share/doc/sqlite-3.53.4
}

# 8.53. mpdecimal-4.0.1
p_mpdecimal() {
    ./configure --prefix=/usr    \
                --disable-static \
                --docdir=/usr/share/doc/mpdecimal-4.0.1
    make
    # the book's test:
    #   make check_local
    make install
}

# 8.54. Python-3.14.7
p_python() {
    patch -Np1 -i ../Python-3.14.7-openssl_4-1.patch
    # s390x: without the book's --enable-optimizations, which builds Python
    # twice and runs its test suite in between to see where the time goes -
    # under qemu, where the time goes somewhere else entirely
    ./configure --prefix=/usr          \
                --enable-shared        \
                --with-system-expat    \
                --without-static-libpython
    make
    # the book's test:
    #   make test TESTOPTS="--timeout 120"
    make install
    cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF
    install -v -dm755 /usr/share/doc/python-3.14.7/html

    tar --strip-components=1  \
        --no-same-owner       \
        --no-same-permissions \
        -C /usr/share/doc/python-3.14.7/html \
        -xvf ../python-3.14.7-docs-html.tar.bz2
}

# 8.55. Flit-Core-4.0.2
p_flit_core() {
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --find-links dist flit_core
}

# 8.56. Packaging-26.3
p_packaging() {
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --find-links dist packaging
}

# 8.57. Wheel-0.48.0
p_wheel() {
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --find-links dist wheel
}

# 8.58. Setuptools-84.0.0
p_setuptools() {
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --find-links dist setuptools
}

# 8.59. Meson-1.12.0
p_meson() {
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --find-links dist meson
    install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
    install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
}

# 8.60. Kmod-34.2
p_kmod() {
    mkdir -p build
    cd       build

    meson setup --prefix=/usr ..    \
                --buildtype=release \
                -D manpages=false
    ninja
    ninja install
}

# 8.61. Coreutils-9.11
p_coreutils() {
    patch -Np1 -i ../coreutils-9.11-i18n-1.patch
    autoreconf -fv
    automake -af
    FORCE_UNSAFE_CONFIGURE=1 ./configure \
                --prefix=/usr
    make
    # the book's test:
    #   make NON_ROOT_USERNAME=tester check-root
    # the book's test:
    #   groupadd -g 102 dummy -U tester
    # the book's test:
    #   chown -R tester .
    # the book's test:
    #   su tester -c "PATH=$PATH make -k RUN_EXPENSIVE_TESTS=yes check" \
    #      < /dev/null
    # the book's test:
    #   groupdel dummy
    make install
    mv -v /usr/bin/chroot /usr/sbin
    mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
    sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
}

# 8.62. Diffutils-3.12
p_diffutils() {
    ./configure --prefix=/usr
    make
    # the book's test:
    #   make check
    make install
}

# 8.63. Findutils-4.11.0
p_findutils() {
    ./configure --prefix=/usr --localstatedir=/var/lib/locate
    make
    # the book's test:
    #   chown -R tester .
    #   su tester -c "PATH=$PATH make check -k"
    make install
}

# 8.64. Groff-1.24.1
p_groff() {
    # unattended: <paper_size>
    PAGE=A4 ./configure --prefix=/usr
    make -j1
    # the book's test:
    #   make check
    make install
}

# 8.66. Gzip-1.14
p_gzip() {
    ./configure --prefix=/usr
    make
    # the book's test:
    #   make check
    make install
}

# 8.67. IPRoute2-7.1.0
p_iproute2() {
    sed -i /ARPD/d Makefile
    rm -fv man/man8/arpd.8
    make NETNS_RUN_DIR=/run/netns
    make SBINDIR=/usr/sbin install
    install -vDm644 COPYING README* -t /usr/share/doc/iproute2-7.1.0
}

# 8.68. Kbd-2.10.0
p_kbd() {
    patch -Np1 -i ../kbd-2.10.0-backspace-1.patch
    sed -i '/RESIZECONS_PROGS=/s/yes/no/' configure
    sed -i 's/resizecons.8 //' docs/man/man8/Makefile.in
    ./configure --prefix=/usr --disable-vlock
    make
    # the book's test:
    #   make check
    make install
    cp -R -v docs/doc -T /usr/share/doc/kbd-2.10.0
}

# 8.69. Libpipeline-1.5.8
p_libpipeline() {
    ./configure --prefix=/usr
    make
    make install
}

# 8.70. Make-4.4.1
p_make() {
    ./configure --prefix=/usr
    make
    # the book's test:
    #   chown -R tester .
    #   su tester -c "PATH=$PATH make check"
    make install
}

# 8.71. Patch-2.8
p_patch() {
    ./configure --prefix=/usr
    make
    # the book's test:
    #   make check
    make install
}

# 8.72. Tar-1.35
p_tar() {
    patch -Np1 -i ../tar-1.35-acl_fix-1.patch
    FORCE_UNSAFE_CONFIGURE=1  \
    ./configure --prefix=/usr
    make
    # the book's test:
    #   make check
    make install
    make -C doc install-html docdir=/usr/share/doc/tar-1.35
}

# 8.73. Texinfo-7.3
p_texinfo() {
    ./configure --prefix=/usr
    make
    # the book's test:
    #   make check
    make install
    make TEXMF=/usr/share/texmf install-tex
    pushd /usr/share/info
      rm -v dir
      for f in *
        do install-info $f dir 2>/dev/null
      done
    popd
}

# 8.74. Vim-9.2.1025
p_vim() {
    echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
    ./configure --prefix=/usr
    make
    # the book's test:
    #   chown -R tester .
    #   sed '/test_plugin_glvs/d' -i src/testdir/Make_all.mak
    # the book's test:
    #   su tester -c "TERM=xterm-256color LANG=en_US.UTF-8 make -j1 test" \
    #      &> vim-test.log
    make install
    ln -sv vim /usr/bin/vi
    for L in  /usr/share/man/{,*/}man1/vim.1; do
        ln -sv vim.1 $(dirname $L)/vi.1
    done
    ln -sv ../vim/vim92/doc /usr/share/doc/vim-9.2.1025
    cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set nocompatible
set backspace=2
set mouse=
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF
    # (vim -c ':options' is the book showing the reader around)
}

# 8.75. MarkupSafe-3.0.3
p_markupsafe() {
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --find-links dist Markupsafe
}

# 8.76. Jinja2-3.1.6
p_jinja2() {
    pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
    pip3 install --no-index --find-links dist Jinja2
}

# 8.77. Systemd-261.2
p_systemd() {
    sed -e 's/GROUP="render"/GROUP="video"/' \
        -e 's/GROUP="sgx", //'               \
        -i rules.d/50-udev-default.rules.in
    mkdir -p build
    cd       build

    meson setup ..                \
          --prefix=/usr           \
          --buildtype=release     \
          -D default-dnssec=no    \
          -D firstboot=false      \
          -D install-tests=false  \
          -D ldconfig=false       \
          -D sysusers=false       \
          -D rpmmacrosdir=no      \
          -D homed=disabled       \
          -D man=disabled         \
          -D mode=release         \
          -D pamconfdir=no        \
          -D dev-kvm-mode=0660    \
          -D nobody-group=nogroup \
          -D sysupdate=disabled   \
          -D ukify=disabled       \
          -D docdir=/usr/share/doc/systemd-261.2
    ninja
    # the book's test:
    #   echo 'NAME="Linux From Scratch"' > /etc/os-release
    #   unshare -m ninja test
    ninja install
    tar -xf ../../systemd-man-pages-261.2.tar.xz \
        --no-same-owner --strip-components=1     \
        -C /usr/share/man
    systemd-machine-id-setup
    systemctl preset-all
}

# 8.78. D-Bus-1.16.2
p_d_bus() {
    mkdir build
    cd    build

    meson setup --prefix=/usr --buildtype=release --wrap-mode=nofallback ..
    ninja
    # the book's test:
    #   ninja test
    ninja install
    ln -sfv /etc/machine-id /var/lib/dbus
}

# 8.79. Man-DB-2.13.1
p_man_db() {
    ./configure --prefix=/usr                         \
                --docdir=/usr/share/doc/man-db-2.13.1 \
                --sysconfdir=/etc                     \
                --disable-setuid                      \
                --enable-cache-owner=bin              \
                --with-browser=/usr/bin/lynx          \
                --with-vgrind=/usr/bin/vgrind         \
                --with-grap=/usr/bin/grap
    make
    # the book's test:
    #   make check
    make install
}

# 8.80. Procps-ng-4.0.7
p_procps_ng() {
    ./configure --prefix=/usr                           \
                --docdir=/usr/share/doc/procps-ng-4.0.7 \
                --disable-static                        \
                --disable-kill                          \
                --enable-watch8bit                      \
                --with-systemd
    make
    # the book's test:
    #   chown -R tester .
    #   su tester -c "PATH=$PATH make check"
    make install
}

# 8.81. Util-linux-2.42.2
p_util_linux() {
    ./configure --bindir=/usr/bin     \
                --libdir=/usr/lib     \
                --runstatedir=/run    \
                --sbindir=/usr/sbin   \
                --disable-chfn-chsh   \
                --disable-login       \
                --disable-nologin     \
                --disable-su          \
                --disable-setpriv     \
                --disable-runuser     \
                --disable-pylibmount  \
                --disable-liblastlog2 \
                --disable-static      \
                --without-python      \
                ADJTIME_PATH=/var/lib/hwclock/adjtime \
                --docdir=/usr/share/doc/util-linux-2.42.2
    make
    # the book's test:
    #   bash tests/run.sh --srcdir=$PWD --builddir=$PWD
    # the book's test:
    #   touch /etc/fstab
    #   chown -R tester .
    #   su tester -c "make -k check"
    make install
}

# 8.82. E2fsprogs-1.47.4
p_e2fsprogs() {
    mkdir -v build
    cd       build
    ../configure --prefix=/usr       \
                 --sysconfdir=/etc   \
                 --enable-elf-shlibs \
                 --disable-libblkid  \
                 --disable-libuuid   \
                 --disable-uuidd     \
                 --disable-fsck
    make
    # the book's test:
    #   make check
    make install
    rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
    gunzip -v /usr/share/info/libext2fs.info.gz
    install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
    makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
    install -v -m644 doc/com_err.info /usr/share/info
    install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
    sed 's/metadata_csum_seed,//' -i /etc/mke2fs.conf
}

# 8.84. Stripping
p_stripping() {
    # s390x: the dynamic linker is ld64.so.1, not ld-linux-something
    save_usrlib="$(cd /usr/lib; ls ld64.so.1)
                 libc.so.6
                 libthread_db.so.1
                 libquadmath.so.0.0.0
                 libstdc++.so.6.0.36
                 libitm.so.1.0.0
                 libatomic.so.1.2.0"

    cd /usr/lib

    # s390x: the book names the libraries of an x86_64 system, and not every one
    # of them exists here (no libquadmath - long double is a quad already)
    for LIB in $save_usrlib; do
        [ -f $LIB ] || continue
        objcopy --only-keep-debug --compress-debug-sections=zstd $LIB $LIB.dbg
        cp $LIB /tmp/$LIB
        strip --strip-unneeded /tmp/$LIB
        objcopy --add-gnu-debuglink=$LIB.dbg /tmp/$LIB
        install -vm755 /tmp/$LIB /usr/lib
        rm /tmp/$LIB
    done

    online_usrbin="bash find strip"
    online_usrlib="libbfd-2.47.20260726.so
                   libsframe.so.3.0.0
                   libhistory.so.8.3
                   libncursesw.so.6.6
                   libm.so.6
                   libreadline.so.8.3
                   libz.so.1.3.2
                   libzstd.so.1.5.7
                   $(cd /usr/lib; find libnss*.so* -type f)"

    for BIN in $online_usrbin; do
        cp /usr/bin/$BIN /tmp/$BIN
        strip --strip-unneeded /tmp/$BIN
        install -vm755 /tmp/$BIN /usr/bin
        rm /tmp/$BIN
    done

    for LIB in $online_usrlib; do
        [ -f /usr/lib/$LIB ] || continue
        cp /usr/lib/$LIB /tmp/$LIB
        strip --strip-unneeded /tmp/$LIB
        install -vm755 /tmp/$LIB /usr/lib
        rm /tmp/$LIB
    done

    for i in $(find /usr/lib -type f -name \*.so* ! -name \*dbg) \
             $(find /usr/lib -type f -name \*.a)                 \
             $(find /usr/{bin,sbin,libexec} -type f); do
        case "$online_usrbin $online_usrlib $save_usrlib" in
            *$(basename $i)* )
                ;;
            * ) strip --strip-unneeded $i || true     # unattended: a script is not an ELF file, and the book shrugs
                ;;
        esac
    done

    unset BIN LIB save_usrlib online_usrbin online_usrlib
}

# 8.85. Cleaning Up
p_cleaning_up() {
    rm -rf /tmp/{*,.*}
    find /usr/lib /usr/libexec -name \*.la -delete
    find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf
    userdel -r tester
}

step 8.3-man-pages                'man-pages-6.18.tar.xz' p_man_pages
step 8.4-iana-etc                 'iana-etc-20260805.tar.gz' p_iana_etc
step 8.5-glibc                    'glibc-2.44.tar.xz' p_glibc
step 8.6-zlib                     'zlib-1.3.2.tar.gz' p_zlib
step 8.7-bzip2                    'bzip2-1.0.8.tar.gz' p_bzip2
step 8.8-xz                       'xz-5.8.3.tar.xz' p_xz
step 8.9-lz4                      'lz4-1.10.0.tar.gz' p_lz4
step 8.10-zstd                    'zstd-1.5.7.tar.gz' p_zstd
step 8.11-file                    'file-5.48.tar.gz' p_file
step 8.12-readline                'readline-8.3.tar.gz' p_readline
step 8.13-pcre2                   'pcre2-10.47.tar.bz2' p_pcre2
step 8.14-m4                      'm4-1.4.21.tar.xz' p_m4
step 8.15-bc                      'bc-7.0.3.tar.xz' p_bc
step 8.16-flex                    'flex-2.6.4.tar.gz' p_flex
step 8.17-tcl                     'tcl8.6.18-src.tar.gz' p_tcl
step 8.18-expect                  'expect5.45.4.tar.gz' p_expect
step 8.19-dejagnu                 'dejagnu-1.6.3.tar.gz' p_dejagnu
step 8.20-ninja                   'ninja-1.13.2.tar.gz' p_ninja
step 8.21-pkgconf                 'pkgconf-3.0.5.tar.xz' p_pkgconf
step 8.22-binutils                'binutils-2.47.tar.xz' p_binutils
step 8.23-gmp                     'gmp-6.3.0.tar.xz' p_gmp
step 8.24-mpfr                    'mpfr-4.2.2.tar.xz' p_mpfr
step 8.25-mpc                     'mpc-1.4.1.tar.xz' p_mpc
step 8.26-attr                    'attr-2.6.0.tar.gz' p_attr
step 8.27-acl                     'acl-2.4.0.tar.xz' p_acl
step 8.28-libcap                  'libcap-2.78.tar.xz' p_libcap
step 8.29-libxcrypt               'libxcrypt-4.5.2.tar.xz' p_libxcrypt
step 8.30-shadow                  'shadow-4.20.2.tar.xz' p_shadow
step 8.31-gawk                    'gawk-5.4.1.tar.xz' p_gawk
step 8.32-gcc                     'gcc-16.2.0.tar.xz' p_gcc
step 8.33-ncurses                 'ncurses-6.6.tar.gz' p_ncurses
step 8.34-sed                     'sed-4.10.tar.xz' p_sed
step 8.35-psmisc                  'psmisc-23.7.tar.xz' p_psmisc
step 8.36-gettext                 'gettext-1.0.tar.xz' p_gettext
step 8.37-bison                   'bison-3.8.2.tar.xz' p_bison
step 8.38-grep                    'grep-3.12.tar.xz' p_grep
step 8.39-bash                    'bash-5.3.tar.gz' p_bash
step 8.40-libtool                 'libtool-2.6.2.tar.xz' p_libtool
step 8.41-gdbm                    'gdbm-1.26.tar.gz' p_gdbm
step 8.42-gperf                   'gperf-3.3.tar.gz' p_gperf
step 8.43-expat                   'expat-2.8.3.tar.xz' p_expat
step 8.44-inetutils               'inetutils-2.8.tar.gz' p_inetutils
step 8.45-less                    'less-704.tar.gz' p_less
step 8.46-perl                    'perl-5.44.0.tar.xz' p_perl
step 8.47-autoconf                'autoconf-2.73.tar.xz' p_autoconf
step 8.48-automake                'automake-1.18.1.tar.xz' p_automake
step 8.49-openssl                 'openssl-4.0.1.tar.gz' p_openssl
step 8.50-libelf-from-elfutils    'elfutils-0.195.tar.bz2' p_libelf_from_elfutils
step 8.51-libffi                  'libffi-3.8.0.tar.gz' p_libffi
step 8.52-sqlite                  'sqlite-autoconf-3530400.tar.gz' p_sqlite
step 8.53-mpdecimal               'mpdecimal-4.0.1.tar.gz' p_mpdecimal
step 8.54-python                  'Python-3.14.7.tar.xz' p_python
step 8.55-flit-core               'flit_core-4.0.2.tar.gz' p_flit_core
step 8.56-packaging               'packaging-26.3.tar.gz' p_packaging
step 8.57-wheel                   'wheel-0.48.0.tar.gz' p_wheel
step 8.58-setuptools              'setuptools-84.0.0.tar.gz' p_setuptools
step 8.59-meson                   'meson-1.12.0.tar.gz' p_meson
step 8.60-kmod                    'kmod-34.2.tar.xz' p_kmod
step 8.61-coreutils               'coreutils-9.11.tar.xz' p_coreutils
step 8.62-diffutils               'diffutils-3.12.tar.xz' p_diffutils
step 8.63-findutils               'findutils-4.11.0.tar.xz' p_findutils
step 8.64-groff                   'groff-1.24.1.tar.gz' p_groff
# s390x: no 8.65 GRUB - it knows nothing of this machine. What loads the kernel
# here is the list-directed IPL of the .ins file, and later zipl (S4).
step 8.66-gzip                    'gzip-1.14.tar.xz' p_gzip
step 8.67-iproute2                'iproute2-7.1.0.tar.xz' p_iproute2
step 8.68-kbd                     'kbd-2.10.0.tar.xz' p_kbd
step 8.69-libpipeline             'libpipeline-1.5.8.tar.gz' p_libpipeline
step 8.70-make                    'make-4.4.1.tar.gz' p_make
step 8.71-patch                   'patch-2.8.tar.xz' p_patch
step 8.72-tar                     'tar-1.35.tar.xz' p_tar
step 8.73-texinfo                 'texinfo-7.3.tar.xz' p_texinfo
step 8.74-vim                     'vim-9.2.1025.tar.gz' p_vim
step 8.75-markupsafe              'markupsafe-3.0.3.tar.gz' p_markupsafe
step 8.76-jinja2                  'jinja2-3.1.6.tar.gz' p_jinja2
step 8.77-systemd                 'systemd-261.2.tar.gz' p_systemd
step 8.78-d-bus                   'dbus-1.16.2.tar.xz' p_d_bus
step 8.79-man-db                  'man-db-2.13.1.tar.xz' p_man_db
step 8.80-procps-ng               'procps-ng-4.0.7.tar.xz' p_procps_ng
step 8.81-util-linux              'util-linux-2.42.2.tar.xz' p_util_linux
step 8.82-e2fsprogs               'e2fsprogs-1.47.4.tar.gz' p_e2fsprogs
step 8.84-stripping               '' p_stripping
step 8.85-cleaning-up             '' p_cleaning_up
echo "chapter 8 is done"
