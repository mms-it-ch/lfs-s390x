#!/bin/bash
# LFS 13.1 chapters 9 to 11, inside the chroot: what makes the tree of chapter
# 8 a system that starts. Unlike chapters 5 to 8 this is not the book's
# commands with a few corrections - the book asks the reader here what kind of
# machine it is, and this is the answer for one z/Architecture processor whose
# console is the service processor, whose disk is a 3390 and whose clock is a
# TOD clock running on UTC. The files are the book's where it has one.
set -e
. /sources/scripts/common.sh

network() {
    # 9.2: no interface yet (S3 has none; CTC or OSA come later), so nothing
    # to wait for and nobody to ask for names
    systemctl disable systemd-networkd-wait-online
    systemctl disable systemd-resolved
    echo lfs > /etc/hostname
    cat > /etc/hosts << "EOF"
# Begin /etc/hosts

127.0.0.1 localhost.localdomain localhost
127.0.1.1 lfs.localdomain lfs
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters

# End /etc/hosts
EOF
}

# 9.2 again, with a network this time: a channel-to-channel adapter - CTCI in
# a Hercules configuration, "0E20.2 CTCI <guest> <gateway>", which on Windows
# needs the TunTap driver. Two subchannels, X'E20' to read and X'E21' to write, that
# the kernel's ctcm driver has to be told belong together (a ccwgroup) before
# it makes an interface of them - called slce20 by this kernel, "slc" and the
# device number, not the ctc0 of the older driver (found on 23.09.2026, with an
# interface that stood there without an address). Then the interface is a
# point-to-point link with one machine at each end, and systemd-networkd gives
# it its addresses.
# The other end is whatever the emulator puts behind the adapter - a gateway
# that turns TCP and UDP into sockets of the host, here - so the name server
# has to be a real one out there, and 1.1.1.1 is. A machine without the
# adapter boots the same volume, and the unit is skipped: its condition is
# the read subchannel's existence.
ctc() {
    cat > /etc/systemd/system/ctc.service << "EOF"
[Unit]
Description=Channel-to-channel adapter 0E20/0E21 as slce20
DefaultDependencies=no
After=systemd-udevd.service
Before=systemd-networkd.service network-pre.target
Wants=network-pre.target
# Only where the adapter is: on Hercules without one, grouping devices that
# are not there hung the boot for two minutes before it failed (23.09.2026)
ConditionPathExists=/sys/bus/ccw/devices/0.0.0e20

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'echo 0.0.0e20,0.0.0e21 > /sys/bus/ccwgroup/drivers/ctcm/group && echo 1 > /sys/bus/ccwgroup/devices/0.0.0e20/online'

[Install]
WantedBy=multi-user.target
EOF
    mkdir -pv /etc/systemd/network
    rm -f /etc/systemd/network/10-ctc0.network
    cat > /etc/systemd/network/10-ctc.network << "EOF"
[Match]
Name=slce20

[Network]
DNS=1.1.1.1

[Address]
Address=192.168.50.2/32
Peer=192.168.50.1/32

[Route]
Gateway=192.168.50.1
GatewayOnLink=yes
EOF
    cat > /etc/resolv.conf << "EOF"
# Begin /etc/resolv.conf

nameserver 1.1.1.1

# End /etc/resolv.conf
EOF
    systemctl enable ctc.service systemd-networkd
}

clock() {
    # 9.5: the TOD clock is UTC, which is what systemd assumes when there is
    # no /etc/adjtime; and no network, so nobody to ask the time of
    systemctl disable systemd-timesyncd
}

console() {
    # 9.6: there is no virtual console on this architecture and so no
    # vconsole.conf. The line-mode console is a typewriter: no cursor, no
    # colours, no escape sequences - and systemd is told so
    mkdir -pv /etc/systemd/system/serial-getty@sclp_line0.service.d
    cat > /etc/systemd/system/serial-getty@sclp_line0.service.d/dumb.conf << "EOF"
[Service]
Environment=TERM=dumb
EOF
    # systemd's getty generator starts a second getty on this architecture,
    # on ttysclp0 (the VT220 flavour of the same SCLP console): a second
    # login prompt on the same line, and, TERM being vt220 there, systemd's
    # terminal reset (ESC[!p ESC]104 ...) and size probe (ESC7 ESC[32766;32766H
    # ESC[6n ESC8) as garbage on the typewriter. What is typed reaches
    # sclp_line0 only, so nothing is lost
    systemctl mask serial-getty@ttysclp0.service
    mkdir -pv /etc/systemd/system.conf.d
    cat > /etc/systemd/system.conf.d/console.conf << "EOF"
[Manager]
# One line per unit and no colours: what the operator's console can show
StatusUnitFormat=name
ShowStatus=yes
LogColor=no
# Ten to twenty times the defaults: an emulator runs this kernel at a few
# million instructions a second (22.09.2026: 2.8), and at that pace mounting
# tmpfs did not finish inside the 90 seconds systemd allows, was killed and
# retried - and so was everything else
DefaultTimeoutStartSec=30min
DefaultTimeoutStopSec=10min
DefaultDeviceTimeoutSec=30min
EOF
    # The defaults above reach only units that name no time of their own, and
    # the early ones - systemd-sysctl, journald, udevd - all do (TimeoutSec=90s).
    # A drop-in for the whole type reaches them too: service.d/ is read for
    # every service, mount.d/ for every mount
    mkdir -pv /etc/systemd/system/service.d
    cat > /etc/systemd/system/service.d/slow-machine.conf << "EOF"
[Service]
TimeoutStartSec=30min
TimeoutStopSec=10min
EOF
    # (a mount and a socket have one time for both, and another name for it -
    # TimeoutStartSec in [Mount] is "Unknown key ... ignoring" at every boot,
    # 23.09.2026)
    for type in mount socket; do
        mkdir -pv /etc/systemd/system/$type.d
        cat > /etc/systemd/system/$type.d/slow-machine.conf << EOF
[${type^}]
TimeoutSec=30min
EOF
    done
    # and udev's own patience with a worker, for the same reason
    mkdir -pv /etc/udev
    cat > /etc/udev/udev.conf << "EOF"
event_timeout=1800
EOF
}

locale_() {
    # 9.7: the console speaks EBCDIC, which has room for ASCII and little else
    cat > /etc/locale.conf << "EOF"
LANG=C.UTF-8
EOF
    cat > /etc/profile << "EOF"
# Begin /etc/profile

for i in $(locale); do
  unset ${i%=*}
done

if [[ "$TERM" = linux ]]; then
  export LANG=C.UTF-8
else
  source /etc/locale.conf

  for i in $(locale); do
    key=${i%=*}
    if [[ -v $key ]]; then
      export $key
    fi
  done
fi

# End /etc/profile
EOF
}

inputrc() {
    cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8-bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# End /etc/inputrc
EOF
}

# 9.4: what systemd does on its first boot, done here instead. udevd waits for
# systemd-hwdb-update, which compiles /etc/udev/hwdb.bin on a machine whose
# /etc is older than its /usr - a minute on Hercules, longer on a slower emulator -
# and the getty devices had given up waiting for udev by then (19.09.2026:
# "Timed out waiting for device dev-sclp_line0.device"). Every distribution
# ships the database compiled and /etc marked up to date; so does this one.
first_boot_done() {
    systemd-hwdb update
    ls -la /etc/udev/hwdb.bin
    /usr/lib/systemd/systemd-update-done
    ls -la /etc/.updated /var/.updated
}

fstab() {
    # 10.2: one 3390, one partition (tools/mkdasd.py), no swap
    cat > /etc/fstab << "EOF"
# Begin /etc/fstab

# file system  mount-point  type     options             dump  fsck
#                                                              order

/dev/dasda1    /            ext4     defaults            1     1

# End /etc/fstab
EOF
}

# 10.4: what GRUB is on a PC is zipl here (s390-tools, tools/lfs/s390-tools.sh).
# It cannot run in the chroot - it asks the block device for its geometry and
# the file system for the blocks the kernel lies in - so this writes only what
# it reads: the configuration, and the command line as a file. The kernel
# itself is put into /boot by tools/mklfs.sh. On the running system:
#   zipl        (reads /etc/zipl.conf, writes the IPL records and /boot/bootmap)
shells() {
    # 9.9
    cat > /etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF
}

# 10.3: the kernel, built here by the system's own compiler as the book has
# it, modules and all. The book configures it by hand (make menuconfig) from
# make defconfig and a list of what systemd needs; unattended, the list and
# this machine's devices are laid over defconfig from config/lfs.config -
# the fragment the cross-built kernel of the first boots was made from, with
# modules this time - and olddefconfig settles the rest.
kernel() {
    make mrproper
    make defconfig
    sed -e 's/^# CONFIG_MODULES is not set/CONFIG_MODULES=y/' \
        /sources/config/lfs.config > lfs.config
    cat >> lfs.config << "EOF"
# Over the defconfig: its z13 and its thousand hertz give way to the
# fragment's z10 and hundred, and a kernel nobody debugs with gdb carries no
# DWARF - the defconfig's costs an hour and a gigabyte
# CONFIG_MARCH_Z13 is not set
# CONFIG_HZ_1000 is not set
CONFIG_NR_CPUS=4
CONFIG_DEBUG_INFO_NONE=y
# CONFIG_DEBUG_INFO_DWARF4 is not set
EOF
    scripts/kconfig/merge_config.sh -m .config lfs.config
    make olddefconfig
    make
    make modules_install
    mkdir -pv /boot
    # s390x: the image of this architecture; unattended: -v for the book's -iv
    cp -v arch/s390/boot/bzImage /boot/vmlinuz-7.1.8-lfs-13.1-systemd
    cp -v System.map /boot/System.map-7.1.8
    cp -v .config /boot/config-7.1.8
    cp -r Documentation -T /usr/share/doc/linux-7.1.8
}

# TERM=dumb on the kernel's command line is PID 1's TERM: systemd then
# leaves out its ephemeral status lines - the "[***  ] Job ... running" it
# redraws in place with a carriage return, which the line-mode console shows
# as a line each - and every escape sequence. The getty's own TERM is set
# in 9.6; this is the one for the boot before the getty.
zipl_conf() {
    mkdir -pv /boot
    cat > /boot/parmfile << "EOF"
dasd=0.0.0120 root=/dev/dasda1 ro rootwait norandmaps TERM=dumb
EOF
    cat > /etc/zipl.conf << "EOF"
[defaultboot]
defaultmenu = menu

:menu
target = /boot
1 = lfs
default = 1
prompt = 0
timeout = 0

[lfs]
target = /boot
image = /boot/vmlinuz-7.1.8-lfs-13.1-systemd
parmfile = /boot/parmfile
EOF
}

the_end() {
    echo 13.1-systemd > /etc/lfs-release
    cat > /etc/lsb-release << "EOF"
DISTRIB_ID="Linux From Scratch"
DISTRIB_RELEASE="13.1-systemd"
DISTRIB_CODENAME="s390x"
DISTRIB_DESCRIPTION="Linux From Scratch"
EOF
    cat > /etc/os-release << "EOF"
NAME="Linux From Scratch"
VERSION="13.1-systemd"
ID=lfs
PRETTY_NAME="Linux From Scratch 13.1-systemd (s390x)"
VERSION_CODENAME="s390x"
HOME_URL="https://www.linuxfromscratch.org/lfs/"
RELEASE_TYPE="stable"
EOF
}

step 9.2-network  '' network
step 9.3-ctc      '' ctc
step 9.4-first-boot-done '' first_boot_done
step 9.5-clock    '' clock
step 9.6-console  '' console
step 9.7-locale   '' locale_
step 9.8-inputrc  '' inputrc
step 9.9-shells   '' shells
step 10.2-fstab   '' fstab
step 10.3-kernel  linux-7.1.8.tar.xz kernel
step 10.4-zipl-conf '' zipl_conf
step 11.1-the-end '' the_end
echo "chapters 9 to 11 are done"
